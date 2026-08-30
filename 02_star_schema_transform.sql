-- ============================================================
-- BI-360-Report | Camada Dimensional (Star Schema)
-- Portfólio: Nathália Paccelly | github.com/NPaccelly
-- Objetivo: padronizar nomenclaturas, formatos de data e granularidades
-- das 13 fontes de staging (stg_*) em um modelo estrela único,
-- pronto para consumo no Power BI (importação ou DirectQuery).
--
-- Dialeto de referência: PostgreSQL / MySQL 8+.
-- Notas de portabilidade:
--   - CREATE TABLE ... AS SELECT (CTAS) funciona em Postgres/MySQL/Snowflake/BigQuery.
--     Em SQL Server, trocar por: SELECT ... INTO nova_tabela FROM ...
--   - Concatenação de string usa || (Postgres). Em SQL Server/MySQL, usar CONCAT().
-- ============================================================

-- ------------------------------------------------------------
-- DIM_CALENDARIO — grão: 1 linha por dia
-- Gerada de forma independente (date spine) para cobrir todo o
-- período analisado, mesmo em dias sem venda/campanha registrada.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS Dim_Calendario;
CREATE TABLE Dim_Calendario (
    Data_Key    DATE PRIMARY KEY,
    Ano         INTEGER,
    Mes         INTEGER,
    Nome_Mes    VARCHAR(15),
    Trimestre   VARCHAR(2),
    Dia_Semana  VARCHAR(10)
);
-- Popular com uma date spine de 2026-01-01 a 2026-06-30 (rotina recursiva
-- ou tabela numérica auxiliar — ver 04_powerbi_guide para a versão
-- equivalente em Power Query M, que é a abordagem usada no relatório final).

-- ------------------------------------------------------------
-- DIM_PRODUTO — grão: 1 linha por SKU
-- ------------------------------------------------------------
DROP TABLE IF EXISTS Dim_Produto;
CREATE TABLE Dim_Produto AS
SELECT
    cod_produto     AS Produto_Key,
    descricao       AS Descricao_Produto,
    categoria       AS Categoria,
    preco_venda     AS Preco_Venda,
    custo_unitario  AS Custo_Unitario
FROM stg_cadastro_produtos;

-- ------------------------------------------------------------
-- DIM_LOJA — grão: 1 linha por loja física (+ registro sintético 'ONLINE')
-- ------------------------------------------------------------
DROP TABLE IF EXISTS Dim_Loja;
CREATE TABLE Dim_Loja AS
SELECT
    cod_loja    AS Loja_Key,
    nome_loja   AS Nome_Loja,
    cidade_uf   AS Cidade_UF,
    regiao      AS Regiao
FROM stg_cadastro_lojas
UNION ALL
SELECT 'ONLINE', 'E-commerce (todos os canais digitais)', 'Nacional', 'Nacional';

-- ------------------------------------------------------------
-- DIM_CAMPANHA — grão: 1 linha por campanha (une as 3 plataformas de mídia)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS Dim_Campanha;
CREATE TABLE Dim_Campanha AS
SELECT
    cod_campanha    AS Campanha_Key,
    nome_campanha   AS Nome_Campanha,
    data_inicio     AS Data_Inicio,
    data_fim        AS Data_Fim,
    plataforma      AS Plataforma
FROM stg_cadastro_campanhas;

-- ------------------------------------------------------------
-- FACT_VENDAS — grão: 1 linha por venda/produto/dia/canal
-- Une Varejo (data DD/MM/AAAA) e E-commerce (data AAAA-MM-DD),
-- padronizando ambos para Data_Key em DATE, e normalizando
-- Receita_Bruta / Receita_Liquida (e-commerce aplica cupom, varejo não).
-- ------------------------------------------------------------
DROP TABLE IF EXISTS Fact_Vendas;
CREATE TABLE Fact_Vendas (
    Data_Key         DATE,
    Canal            VARCHAR(15),
    Loja_Key         VARCHAR(10),
    Produto_Key      VARCHAR(5),
    Qtd_Vendida      INTEGER,
    Receita_Bruta    DECIMAL(12,2),
    Receita_Liquida  DECIMAL(12,2)
);

-- Varejo: converte DD/MM/AAAA -> DATE
INSERT INTO Fact_Vendas
SELECT
    TO_DATE(Data_Venda, 'DD/MM/YYYY')  AS Data_Key,   -- SQL Server: CONVERT(date, Data_Venda, 103)
    'Varejo'                            AS Canal,
    Cod_Loja                            AS Loja_Key,
    Cod_Produto                         AS Produto_Key,
    Qtd_Vendida,
    Valor_Total_RS                      AS Receita_Bruta,
    Valor_Total_RS                      AS Receita_Liquida    -- sem desconto no varejo
FROM stg_vendas_varejo;

-- E-commerce: data já em ISO; aplica net_value (pós-cupom) como receita líquida
INSERT INTO Fact_Vendas
SELECT
    order_date          AS Data_Key,
    'E-commerce'         AS Canal,
    'ONLINE'             AS Loja_Key,
    sku                  AS Produto_Key,
    quantity             AS Qtd_Vendida,
    gross_value          AS Receita_Bruta,
    net_value            AS Receita_Liquida
FROM stg_vendas_ecommerce;

-- ------------------------------------------------------------
-- FACT_CAMPANHA — grão: 1 linha por campanha/plataforma/dia
-- Une Meta, Google e TikTok num único fato de mídia paga.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS Fact_Campanha;
CREATE TABLE Fact_Campanha (
    Data_Key        DATE,
    Campanha_Key    VARCHAR(5),
    Plataforma      VARCHAR(20),
    Impressoes      INTEGER,
    Cliques         INTEGER,
    Investimento    DECIMAL(12,2),
    Conversoes      INTEGER
);

INSERT INTO Fact_Campanha
SELECT date, campaign_id, 'Meta',   impressions, clicks, spend_brl, conversions FROM stg_campanhas_meta_ads
UNION ALL
SELECT date, campaign_id, 'Google', impressions, clicks, spend_brl, conversions FROM stg_campanhas_google_ads
UNION ALL
SELECT date, campaign_id, 'TikTok', impressions, clicks, spend_brl, conversions FROM stg_campanhas_tiktok_ads;

-- ------------------------------------------------------------
-- FACT_FINANCEIRO — grão: 1 linha por mês/categoria (custo ou receita)
-- Une duas fontes com formatos de mês opostos (MM/AAAA vs AAAA-MM).
-- ------------------------------------------------------------
DROP TABLE IF EXISTS Fact_Financeiro;
CREATE TABLE Fact_Financeiro (
    Mes_Key      VARCHAR(7),   -- AAAA-MM padronizado
    Tipo         VARCHAR(10),  -- 'Custo' | 'Receita'
    Categoria    VARCHAR(30),
    Valor        DECIMAL(14,2)
);

INSERT INTO Fact_Financeiro
SELECT
    SUBSTRING(Mes_Ref, 4, 4) || '-' || SUBSTRING(Mes_Ref, 1, 2)  AS Mes_Key,  -- MM/AAAA -> AAAA-MM
    'Custo'          AS Tipo,
    Centro_Custo     AS Categoria,
    Valor_RS         AS Valor
FROM stg_financeiro_custos;

INSERT INTO Fact_Financeiro
SELECT
    competencia          AS Mes_Key,
    'Receita'             AS Tipo,
    tipo_receita          AS Categoria,
    valor_liquido_brl     AS Valor
FROM stg_financeiro_receita;

-- ------------------------------------------------------------
-- Checagem de integridade pós-carga (usar antes de publicar no Power BI)
-- ------------------------------------------------------------
-- 1) Toda Produto_Key em Fact_Vendas deve existir em Dim_Produto
SELECT DISTINCT fv.Produto_Key
FROM Fact_Vendas fv
LEFT JOIN Dim_Produto dp ON fv.Produto_Key = dp.Produto_Key
WHERE dp.Produto_Key IS NULL;

-- 2) Toda Loja_Key em Fact_Vendas deve existir em Dim_Loja
SELECT DISTINCT fv.Loja_Key
FROM Fact_Vendas fv
LEFT JOIN Dim_Loja dl ON fv.Loja_Key = dl.Loja_Key
WHERE dl.Loja_Key IS NULL;

-- 3) Toda Campanha_Key em Fact_Campanha deve existir em Dim_Campanha
SELECT DISTINCT fc.Campanha_Key
FROM Fact_Campanha fc
LEFT JOIN Dim_Campanha dc ON fc.Campanha_Key = dc.Campanha_Key
WHERE dc.Campanha_Key IS NULL;

-- Resultado esperado: 0 linhas nas três consultas acima (integridade referencial OK).
