# Relatório Multiapresentação — Visão 360°

Case de modelagem de dados e DAX avançado para um relatório de Power BI com 6 painéis integrados, consolidando mais de 12 tabelas de fontes distintas.

> Case fictício desenvolvido para fins de portfólio, com dados simulados — sem vínculo com clientes ou empresas reais.

## Dashboard interativo

[![Ver dashboard no Power BI](https://img.shields.io/badge/Power_BI-Visualizar_Dashboard-F2C811?style=for-the-badge&logo=powerbi&logoColor=black)](https://app.powerbi.com/view?r=eyJrIjoiY2VlNmUwYTEtMGY5MC00ZjkwLWFkZDgtMzQ0NGRmZTljNjBlIiwidCI6ImUxZDJhZjkzLTIzYmEtNDEzNi1hMGY3LTMxNzhmNGE4ZjcyZCJ9)

> Visualização publicada em modo somente leitura (Power BI Publish to Web). Não requer login e não permite download do arquivo original.

## Contexto

O cenário simulado envolve uma empresa do setor de alimentos e bebidas que precisava de uma visão unificada de performance em um contexto com múltiplas fontes de dados, cada uma com nomenclaturas, formatos de data e granularidades diferentes — o que dificultava comparações e análises cross-dimensionais confiáveis.

## Solução

- Modelagem dimensional (*Star Schema*) para integrar 12+ tabelas de fontes distintas
- Padronização de datas, nomenclaturas e códigos entre as bases
- Medidas em *DAX avançado* para análises cross-dimensionais
- Estruturação de 6 painéis: visão geral, por produto, por campanha, retorno financeiro, ROI e comparativo entre períodos
- Pipeline replicado em SQL **e** em Python/pandas, com checklist de qualidade de dados gerado automaticamente

## Resultado

Um relatório único, confiável e navegável, substituindo múltiplas planilhas e análises fragmentadas por uma visão 360° do negócio. Os principais achados analíticos estão consolidados no [Sumário Executivo](BI-360-Report_Sumario_Executivo.docx).

## Estrutura do repositório

| Arquivo | O que é |
|---|---|
| `01_staging_schema_and_load.sql` | Criação e carga das 13 tabelas de origem (staging) |
| `02_star_schema_transform.sql` | Transformação staging → star schema (4 dimensões + 3 fatos) + checagens de integridade |
| `03_consultas_analiticas.sql` | Uma consulta por painel — base lógica das medidas DAX |
| `etl_pandas.py` | Pipeline equivalente em Python/pandas, gera o modelo estrela em CSV + `checklist_qualidade_dados.md` |
| `BI-360-Report_Fontes_de_Dados.xlsx` | As 13 fontes brutas em abas + Dicionário de Dados + Modelo Dimensional + Big Numbers com fórmulas vivas |
| `BI-360-Report_Guia_PowerBI.docx` | Modelo de relacionamentos, passos de Power Query e medidas DAX prontas para os 6 painéis |
| `BI-360-Report_Sumario_Executivo.docx` | Leitura analítica dos 6 painéis: achados, comparações e recomendações |

## Tecnologias

- Power BI
- DAX
- SQL
- Python (pandas)
- Modelagem Dimensional (Star Schema)

## Autora

Nathália Paccelly — Especialista Sênior em Inteligência de Mercado, BI & Comunicação Estratégica
[LinkedIn](#) · [Portfólio](#)
