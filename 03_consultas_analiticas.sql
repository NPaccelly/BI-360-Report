-- ============================================================
-- BI-360-Report | Consultas Analíticas (camada de consumo)
-- Cada bloco corresponde a um dos 6 painéis do relatório e serve
-- de base lógica para as medidas DAX equivalentes no Power BI
-- (ver 04_powerbi_guide.docx).
-- ============================================================

-- ------------------------------------------------------------
-- PAINEL 1 — Visão Geral: Big Numbers do período
-- ------------------------------------------------------------
SELECT
    SUM(Receita_Liquida)                           AS Receita_Liquida_Total,
    SUM(Qtd_Vendida)                               AS Unidades_Vendidas,
    ROUND(SUM(Receita_Liquida) / NULLIF(SUM(Qtd_Vendida),0), 2) AS Ticket_Medio_Unitario,
    COUNT(DISTINCT Data_Key)                       AS Dias_Com_Venda
FROM Fact_Vendas;

-- ------------------------------------------------------------
-- PAINEL 2 — Por Produto: receita, margem e participação
-- ------------------------------------------------------------
SELECT
    dp.Descricao_Produto,
    dp.Categoria,
    SUM(fv.Qtd_Vendida)                                            AS Unidades_Vendidas,
    SUM(fv.Receita_Liquida)                                        AS Receita_Liquida,
    SUM(fv.Qtd_Vendida * dp.Custo_Unitario)                        AS Custo_Total,
    SUM(fv.Receita_Liquida) - SUM(fv.Qtd_Vendida * dp.Custo_Unitario) AS Margem_Bruta,
    ROUND(100.0 * SUM(fv.Receita_Liquida) / SUM(SUM(fv.Receita_Liquida)) OVER (), 1) AS Pct_Participacao_Receita
FROM Fact_Vendas fv
JOIN Dim_Produto dp ON fv.Produto_Key = dp.Produto_Key
GROUP BY dp.Descricao_Produto, dp.Categoria
ORDER BY Receita_Liquida DESC;

-- ------------------------------------------------------------
-- PAINEL 3 — Por Campanha: performance de mídia paga
-- ------------------------------------------------------------
SELECT
    dc.Nome_Campanha,
    dc.Plataforma,
    SUM(fc.Impressoes)                                     AS Impressoes,
    SUM(fc.Cliques)                                        AS Cliques,
    ROUND(100.0 * SUM(fc.Cliques) / NULLIF(SUM(fc.Impressoes),0), 2)  AS CTR_Pct,
    SUM(fc.Investimento)                                   AS Investimento,
    ROUND(SUM(fc.Investimento) / NULLIF(SUM(fc.Cliques),0), 2)        AS CPC_Medio,
    SUM(fc.Conversoes)                                     AS Conversoes,
    ROUND(SUM(fc.Investimento) / NULLIF(SUM(fc.Conversoes),0), 2)     AS CPA_Medio
FROM Fact_Campanha fc
JOIN Dim_Campanha dc ON fc.Campanha_Key = dc.Campanha_Key
GROUP BY dc.Nome_Campanha, dc.Plataforma
ORDER BY Investimento DESC;

-- ------------------------------------------------------------
-- PAINEL 4 — Retorno Financeiro: receita vs. custo por mês
-- ------------------------------------------------------------
SELECT
    Mes_Key,
    SUM(CASE WHEN Tipo = 'Receita' THEN Valor ELSE 0 END)   AS Receita_Mensal,
    SUM(CASE WHEN Tipo = 'Custo'   THEN Valor ELSE 0 END)   AS Custo_Mensal,
    SUM(CASE WHEN Tipo = 'Receita' THEN Valor ELSE 0 END)
      - SUM(CASE WHEN Tipo = 'Custo' THEN Valor ELSE 0 END) AS Resultado_Mensal
FROM Fact_Financeiro
GROUP BY Mes_Key
ORDER BY Mes_Key;

-- ------------------------------------------------------------
-- PAINEL 5 — ROI: retorno sobre investimento em mídia paga
-- (receita atribuída a vendas no período de cada campanha / investimento)
-- ------------------------------------------------------------
SELECT
    dc.Nome_Campanha,
    dc.Plataforma,
    SUM(fc.Investimento)                                          AS Investimento,
    COALESCE(rv.Receita_Periodo_Campanha, 0)                      AS Receita_Periodo_Campanha,
    ROUND(
        (COALESCE(rv.Receita_Periodo_Campanha,0) - SUM(fc.Investimento))
        / NULLIF(SUM(fc.Investimento),0) * 100, 1
    ) AS ROI_Pct
FROM Fact_Campanha fc
JOIN Dim_Campanha dc ON fc.Campanha_Key = dc.Campanha_Key
LEFT JOIN (
    SELECT dc2.Campanha_Key, SUM(fv.Receita_Liquida) AS Receita_Periodo_Campanha
    FROM Dim_Campanha dc2
    JOIN Fact_Vendas fv
      ON fv.Data_Key BETWEEN dc2.Data_Inicio AND dc2.Data_Fim
    GROUP BY dc2.Campanha_Key
) rv ON rv.Campanha_Key = dc.Campanha_Key
GROUP BY dc.Nome_Campanha, dc.Plataforma, rv.Receita_Periodo_Campanha
ORDER BY ROI_Pct DESC;

-- ------------------------------------------------------------
-- PAINEL 6 — Comparativo entre Períodos (mês a mês, com variação %)
-- ------------------------------------------------------------
SELECT
    Mes_Key,
    Receita_Mensal,
    LAG(Receita_Mensal) OVER (ORDER BY Mes_Key)                                   AS Receita_Mes_Anterior,
    ROUND(
        100.0 * (Receita_Mensal - LAG(Receita_Mensal) OVER (ORDER BY Mes_Key))
        / NULLIF(LAG(Receita_Mensal) OVER (ORDER BY Mes_Key), 0), 1
    ) AS Variacao_Pct_MoM
FROM (
    SELECT
        SUBSTRING(CAST(Data_Key AS VARCHAR), 1, 7) AS Mes_Key,
        SUM(Receita_Liquida) AS Receita_Mensal
    FROM Fact_Vendas
    GROUP BY SUBSTRING(CAST(Data_Key AS VARCHAR), 1, 7)
) mensal
ORDER BY Mes_Key;
