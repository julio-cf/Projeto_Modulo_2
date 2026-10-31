-- 1. CRIAR E CONECTAR AO BANCO DE DADOS
CREATE DATABASE IF NOT EXISTS pncp_controladoria;
USE pncp_controladoria;

-- 2. LIMPEZA PRÉVIA (Evita erros ao rodar o script mais de uma vez)
DROP TABLE IF EXISTS fato_item_contratado;
DROP TABLE IF EXISTS dim_localidade;
DROP TABLE IF EXISTS dim_modalidade;
DROP TABLE IF EXISTS dim_fornecedor;
DROP TABLE IF EXISTS dim_orgao;


-- ============================================================================
-- 3. CAMADA DIMENSIONAL
-- ============================================================================

-- Dimensão: Órgão (Quem comprou)
CREATE TABLE dim_orgao (
    sk_orgao INT PRIMARY KEY,                 -- INT com sinal (permite -1)
    cnpj_orgao VARCHAR(20) UNIQUE NOT NULL,   -- Chave natural
    nome_orgao VARCHAR(500),
    poder VARCHAR(50)
);

-- Dimensão: Fornecedor (Quem vendeu)
CREATE TABLE dim_fornecedor (
    sk_fornecedor INT PRIMARY KEY,
    ni_fornecedor VARCHAR(50) UNIQUE NOT NULL,
    nome_fornecedor VARCHAR(500),
    tipo_pessoa VARCHAR(20),
    porte VARCHAR(100)
);

-- Dimensão: Modalidade (Como comprou)
CREATE TABLE dim_modalidade (
    sk_modalidade INT PRIMARY KEY,
    modalidade_id INT UNIQUE NOT NULL,
    nome_modalidade VARCHAR(100)
);

-- Dimensão: Localidade (Onde comprou)
CREATE TABLE dim_localidade (
    sk_localidade INT PRIMARY KEY,
    uf_sigla VARCHAR(5) UNIQUE NOT NULL,
    uf_nome VARCHAR(100),
    regiao VARCHAR(50)
);


-- ============================================================================
-- 4. TABELA FATO
-- ============================================================================

-- Fato: Item Contratado (O que foi comprado)
CREATE TABLE fato_item_contratado (
    sk_fato INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Chaves Naturais da Fato (Grão)
    numero_controle_pncp VARCHAR(100) NOT NULL,
    numero_item INT NOT NULL,
    
    -- Chaves Estrangeiras (FKs)
    sk_orgao INT NOT NULL,
    sk_fornecedor INT NOT NULL,
    sk_modalidade INT NOT NULL,
    sk_localidade INT NOT NULL,
    
    -- Datas
    data_publicacao DATE NOT NULL,
    data_homologacao DATE,              -- Permite NULL quando a regra anula a cronologia
    
    -- Descrição do Item
    descricao_item TEXT,
    perfil_gasto VARCHAR(100),
    
    -- Números / Valores
    quantidade DECIMAL(18,4) NOT NULL CHECK (quantidade > 0),
    valor_unitario_estimado DECIMAL(18,4) CHECK (valor_unitario_estimado >= 0),
    valor_total_estimado DECIMAL(18,2) CHECK (valor_total_estimado >= 0),
    valor_unitario_homologado DECIMAL(18,4) CHECK (valor_unitario_homologado >= 0),
    valor_total_homologado DECIMAL(18,2) CHECK (valor_total_homologado >= 0),
    
    -- Campos Calculados
    comparavel TINYINT,                 -- 1 ou 0
    economia_valor DECIMAL(18,2),
    dias_ciclo INT,
    
    -- Restrições de Integridade (Constraints)
    UNIQUE (numero_controle_pncp, numero_item),
    FOREIGN KEY (sk_orgao) REFERENCES dim_orgao(sk_orgao),
    FOREIGN KEY (sk_fornecedor) REFERENCES dim_fornecedor(sk_fornecedor),
    FOREIGN KEY (sk_modalidade) REFERENCES dim_modalidade(sk_modalidade),
    FOREIGN KEY (sk_localidade) REFERENCES dim_localidade(sk_localidade)
);