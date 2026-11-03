
-- ============================================================
-- PERGUNTAS DA CONTROLADORIA
-- ============================================================

USE pncp_controladoria;


-- ============================================================
-- PERGUNTA 1 - ECONOMIA GLOBAL DO PODER PUBLICO
-- Qual o valor e o percentual economizado pelo governo?
-- Economia: somente itens comparaveis.
-- Volume: todos os itens.
-- ============================================================

SELECT
    COUNT(*) AS total_itens,

    SUM(CASE WHEN comparavel = 1 THEN 1 ELSE 0 END)
        AS itens_comparaveis,

    ROUND(
        100.0 * SUM(CASE WHEN comparavel = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    ) AS itens_comparaveis_pct,

    SUM(valor_total_homologado)
        AS volume_homologado_total,

    SUM(valor_total_estimado)
        AS valor_estimado_todos_itens,

    SUM(CASE WHEN comparavel = 1
        THEN valor_total_estimado ELSE 0 END)
        AS valor_estimado_comparavel,

    SUM(CASE WHEN comparavel = 1
        THEN valor_total_homologado ELSE 0 END)
        AS valor_homologado_comparavel,

    SUM(CASE WHEN comparavel = 1
        THEN economia_valor ELSE 0 END)
        AS economia_nominal,

    ROUND(
        100.0 * SUM(CASE WHEN comparavel = 1
            THEN economia_valor ELSE 0 END)
        / NULLIF(
            SUM(CASE WHEN comparavel = 1
                THEN valor_total_estimado ELSE 0 END),
            0
        ), 2
    ) AS economia_pct

FROM fato_item_contratado;


-- ============================================================
-- PERGUNTA 2 - CONCENTRACAO DE FORNECEDORES
-- Quem sao os 10 maiores fornecedores?
-- Qual percentual do volume esta concentrado neles?
-- Fornecedor identificado pelo CNPJ/CPF limpo.
-- ============================================================

WITH volume_por_fornecedor AS (
    SELECT
        d.ni_fornecedor,
        d.nome_fornecedor,
        COUNT(*) AS quantidade_itens,
        SUM(f.valor_total_homologado)
            AS volume_homologado

    FROM fato_item_contratado AS f

    INNER JOIN dim_fornecedor AS d
        ON f.sk_fornecedor = d.sk_fornecedor

    GROUP BY
        d.ni_fornecedor,
        d.nome_fornecedor
),

top_10 AS (
    SELECT *
    FROM volume_por_fornecedor
    ORDER BY volume_homologado DESC, ni_fornecedor ASC
    LIMIT 10
),

total_geral AS (
    SELECT
        SUM(valor_total_homologado) AS volume_total
    FROM fato_item_contratado
)

SELECT
    ROW_NUMBER() OVER (
        ORDER BY t.volume_homologado DESC,
                 t.ni_fornecedor ASC
    ) AS posicao,

    t.ni_fornecedor,
    t.nome_fornecedor,
    t.quantidade_itens,
    t.volume_homologado,

    ROUND(
        100.0 * t.volume_homologado
        / NULLIF(g.volume_total, 0), 2
    ) AS participacao_fornecedor_pct,

    (SELECT SUM(volume_homologado) FROM top_10)
        AS volume_top_10,

    ROUND(
        100.0 * (
            SELECT SUM(volume_homologado) FROM top_10
        ) / NULLIF(g.volume_total, 0), 2
    ) AS concentracao_top_10_pct

FROM top_10 AS t

CROSS JOIN total_geral AS g

ORDER BY posicao;


-- ============================================================
-- PERGUNTA 3 - EFICACIA POR MODALIDADE
-- Quais modalidades possuem maior economia/desagio?
-- Quais movimentam o maior volume financeiro?
-- Credenciamento nao possui itens comparaveis.
-- ============================================================

WITH totais AS (
    SELECT
        SUM(valor_total_homologado) AS volume_geral,

        SUM(CASE WHEN comparavel = 1
            THEN valor_total_estimado ELSE 0 END)
            AS estimado_comparavel_geral,

        SUM(CASE WHEN comparavel = 1
            THEN economia_valor ELSE 0 END)
            AS economia_geral

    FROM fato_item_contratado
)

SELECT
    m.modalidade_id,
    m.nome_modalidade,

    COUNT(*) AS quantidade_itens,

    SUM(f.valor_total_homologado)
        AS volume_homologado,

    ROUND(
        100.0 * SUM(f.valor_total_homologado)
        / NULLIF(t.volume_geral, 0), 2
    ) AS participacao_volume_pct,

    SUM(CASE WHEN f.comparavel = 1
        THEN 1 ELSE 0 END)
        AS itens_comparaveis,

    SUM(CASE WHEN f.comparavel = 1
        THEN f.economia_valor ELSE 0 END)
        AS economia_nominal,

    ROUND(
        100.0 * SUM(CASE WHEN f.comparavel = 1
            THEN f.economia_valor ELSE 0 END)
        / NULLIF(
            SUM(CASE WHEN f.comparavel = 1
                THEN f.valor_total_estimado ELSE 0 END),
            0
        ), 2
    ) AS economia_pct,

    ROUND(
        100.0 * (
            SUM(CASE WHEN f.comparavel = 1
                THEN f.economia_valor ELSE 0 END)
            / NULLIF(
                SUM(CASE WHEN f.comparavel = 1
                    THEN f.valor_total_estimado ELSE 0 END),
                0
            )
            - t.economia_geral
              / NULLIF(t.estimado_comparavel_geral, 0)
        ), 2
    ) AS diferenca_media_geral_pp

FROM fato_item_contratado AS f

INNER JOIN dim_modalidade AS m
    ON f.sk_modalidade = m.sk_modalidade

CROSS JOIN totais AS t

GROUP BY
    m.modalidade_id,
    m.nome_modalidade,
    t.volume_geral,
    t.economia_geral,
    t.estimado_comparavel_geral

ORDER BY volume_homologado DESC;


-- ============================================================
-- PERGUNTA 4 - TEMPO DO CICLO DE COMPRAS
-- Qual a duracao media por orgao?
-- Agrupar pelo nome padronizado do orgao.
-- Somente orgaos com pelo menos 5 ciclos validos.
-- ============================================================

SELECT
    d.nome_orgao,

    COUNT(DISTINCT d.cnpj_orgao)
        AS unidades_compradoras,

    COUNT(*) AS total_itens,

    COUNT(f.dias_ciclo) AS itens_com_ciclo,

    COUNT(*) - COUNT(f.dias_ciclo)
        AS itens_sem_ciclo,

    ROUND(AVG(f.dias_ciclo), 1)
        AS ciclo_medio_dias,

    MAX(f.dias_ciclo) AS ciclo_maximo_dias

FROM fato_item_contratado AS f

INNER JOIN dim_orgao AS d
    ON f.sk_orgao = d.sk_orgao

GROUP BY d.nome_orgao

HAVING COUNT(f.dias_ciclo) >= 5

ORDER BY
    ciclo_medio_dias DESC,
    itens_com_ciclo DESC;


-- ============================================================
-- PERGUNTA 5A - DISTRIBUICAO POR REGIAO
-- Quais regioes concentram mais despesas?
-- Quais possuem melhores indicadores de desconto?
-- ============================================================

SELECT
    l.regiao,

    COUNT(*) AS quantidade_itens,

    COUNT(DISTINCT f.sk_orgao)
        AS unidades_compradoras,

    SUM(f.valor_total_homologado)
        AS volume_homologado,

    ROUND(
        100.0 * SUM(f.valor_total_homologado)
        / NULLIF(
            (SELECT SUM(valor_total_homologado)
             FROM fato_item_contratado), 0
        ), 2
    ) AS participacao_volume_pct,

    SUM(CASE WHEN f.comparavel = 1
        THEN f.economia_valor ELSE 0 END)
        AS economia_nominal,

    ROUND(
        100.0 * SUM(CASE WHEN f.comparavel = 1
            THEN f.economia_valor ELSE 0 END)
        / NULLIF(
            SUM(CASE WHEN f.comparavel = 1
                THEN f.valor_total_estimado ELSE 0 END),
            0
        ), 2
    ) AS economia_pct

FROM fato_item_contratado AS f

INNER JOIN dim_localidade AS l
    ON f.sk_localidade = l.sk_localidade

GROUP BY l.regiao

ORDER BY volume_homologado DESC;


-- ============================================================
-- PERGUNTA 5B - DISTRIBUICAO POR ESTADO
-- Mesma analise anterior detalhada por UF.
-- ============================================================

SELECT
    l.regiao,
    l.uf_sigla,
    l.uf_nome,

    COUNT(*) AS quantidade_itens,

    COUNT(DISTINCT f.sk_orgao)
        AS unidades_compradoras,

    SUM(f.valor_total_homologado)
        AS volume_homologado,

    ROUND(
        100.0 * SUM(f.valor_total_homologado)
        / NULLIF(
            (SELECT SUM(valor_total_homologado)
             FROM fato_item_contratado), 0
        ), 2
    ) AS participacao_volume_pct,

    SUM(CASE WHEN f.comparavel = 1
        THEN f.economia_valor ELSE 0 END)
        AS economia_nominal,

    ROUND(
        100.0 * SUM(CASE WHEN f.comparavel = 1
            THEN f.economia_valor ELSE 0 END)
        / NULLIF(
            SUM(CASE WHEN f.comparavel = 1
                THEN f.valor_total_estimado ELSE 0 END),
            0
        ), 2
    ) AS economia_pct

FROM fato_item_contratado AS f

INNER JOIN dim_localidade AS l
    ON f.sk_localidade = l.sk_localidade

GROUP BY
    l.regiao,
    l.uf_sigla,
    l.uf_nome

ORDER BY volume_homologado DESC;


-- ============================================================
-- PERGUNTA 6 - PERFIL DOS GASTOS
-- Como os recursos se distribuem entre Bens,
-- Servicos e Obras e engenharia?
-- Perfil calculado anteriormente pelo Python.
-- ============================================================

SELECT
    f.perfil_gasto,

    COUNT(*) AS quantidade_itens,

    SUM(f.valor_total_homologado)
        AS volume_homologado,

    ROUND(
        100.0 * SUM(f.valor_total_homologado)
        / NULLIF(
            (SELECT SUM(valor_total_homologado)
             FROM fato_item_contratado), 0
        ), 2
    ) AS participacao_volume_pct,

    ROUND(
        SUM(f.valor_total_homologado)
        / NULLIF(COUNT(*), 0), 2
    ) AS ticket_medio_item,

    SUM(CASE WHEN f.comparavel = 1
        THEN f.economia_valor ELSE 0 END)
        AS economia_nominal,

    ROUND(
        100.0 * SUM(CASE WHEN f.comparavel = 1
            THEN f.economia_valor ELSE 0 END)
        / NULLIF(
            SUM(CASE WHEN f.comparavel = 1
                THEN f.valor_total_estimado ELSE 0 END),
            0
        ), 2
    ) AS economia_pct

FROM fato_item_contratado AS f

GROUP BY f.perfil_gasto

ORDER BY volume_homologado DESC;