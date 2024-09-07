--Sprint 3

-----------------------------------------------Gatilho------------------------------------------------
--Criação da tabela de auditoria
CREATE TABLE TB_PACIENTE_AUDITORIA(
    CPF NUMBER
    ,NOME_COMPLETO VARCHAR2(100)
    ,DATA_NASC VARCHAR2(10)
    ,END_PACIENTE VARCHAR2(150)
    ,TEL_PACIENTE NUMBER (11)
    ,EMAIL_PACIENTE VARCHAR2(50)
    ,SENHA VARCHAR2(16)
    ,SEXO VARCHAR2(16)
    ,USUARIO VARCHAR2(100)
    ,OPERACAO VARCHAR2 (30)
    ,DATA_OPERACAO DATE
)

--Triger que vê se ouve algum INSERT, UPDATE ou DELETE na tabela TB_PACIENTE
CREATE OR REPLACE TRIGGER TRG_PACIENTE_AUDITORIA
    AFTER INSERT OR UPDATE OR DELETE ON TB_PACIENTE
    FOR EACH ROW
DECLARE
    OPERACAO VARCHAR2(30);
    NOME_USUARIO VARCHAR2(100);
BEGIN
    IF INSERTING THEN
        OPERACAO := 'INSERT';
    ELSIF UPDATING THEN
        OPERACAO := 'UPDATE';
    ELSIF DELETING THEN
        OPERACAO := 'DELETE';
    END IF;

    -- Pegar o nome do usuário que fez a operação
    NOME_USUARIO := SYS_CONTEXT('USERENV', 'SESSION_USER');
    
    -- Inserir dados na tabela de auditoria para operações de INSERT ou UPDATE
    IF INSERTING OR UPDATING THEN
        INSERT INTO TB_PACIENTE_AUDITORIA
            (CPF, NOME_COMPLETO, DATA_NASC, END_PACIENTE, TEL_PACIENTE, 
             EMAIL_PACIENTE, SENHA, SEXO, USUARIO, OPERACAO, DATA_OPERACAO)
        VALUES
            (:NEW.CPF, :NEW.NOME_COMPLETO, :NEW.DATA_NASC, :NEW.END_PACIENTE, :NEW.TEL_PACIENTE, 
             :NEW.EMAIL_PACIENTE, :NEW.SENHA, :NEW.SEXO, NOME_USUARIO, OPERACAO, SYSDATE);
    END IF;

    -- Inserir dados antigos (OLD) na tabela de auditoria para operações de UPDATE ou DELETE
    IF UPDATING OR DELETING THEN
        INSERT INTO TB_PACIENTE_AUDITORIA
            (CPF, NOME_COMPLETO, DATA_NASC, END_PACIENTE, TEL_PACIENTE, 
             EMAIL_PACIENTE, SENHA, SEXO, USUARIO, OPERACAO, DATA_OPERACAO)
        VALUES
            (:OLD.CPF, :OLD.NOME_COMPLETO, :OLD.DATA_NASC, :OLD.END_PACIENTE, :OLD.TEL_PACIENTE, 
             :OLD.EMAIL_PACIENTE, :OLD.SENHA, :OLD.SEXO, NOME_USUARIO, OPERACAO, SYSDATE);
    END IF;
END;
/

-----------------------------------------------Funções------------------------------------------------

--Função que tranforma os dados em formato JSON
CREATE OR REPLACE FUNCTION CONVERSOR_JSON(
    CHAVE   VARCHAR2,
    VALOR VARCHAR2
) RETURN CLOB IS
    JSON_FINAL  CLOB;  
BEGIN

    JSON_FINAL := '{ "' || CHAVE || '": ';

    -- Exceção 1: Verificar se o valor é nulo
    IF VALOR IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Valor nulo não permitido.');
    END IF;

    -- Exceção 2: Verificar o tamanho do valor
    IF LENGTH(VALOR) > 4000 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Valor excede o tamanho máximo permitido.');
    END IF;

    -- Exceção 3: Verificar se o valor é um número válido
    BEGIN
        DECLARE
            NUMERO NUMBER;
        BEGIN
            NUMERO := TO_NUMBER(VALOR);
        EXCEPTION
            WHEN OTHERS THEN

                JSON_FINAL := JSON_FINAL || '"' || VALOR || '"';
        END;
    END;

    JSON_FINAL := JSON_FINAL || '}';

    RETURN JSON_FINAL;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003, 'Erro ao converter para JSON: ' || SQLERRM);
END;
/
to_custom_json
--Função que substitui uma procedure já existente

-----------------------------------------------Procedures-------------------------------------------------

--Procedure com JOIN de duas tabelas relacionais e exibição dos dados em formato JSON.
CREATE OR REPLACE PROCEDURE PROC_CLINICA_UNIDADE_JSON AS
    CURSOR TABELAS IS
        SELECT cli.CNPJ, cli.NOME_CLINICA, uni.END_UNIDADE, uni.TIPO_EXAME
        FROM TB_CLINICA cli
        JOIN TB_UNIDADE uni ON cli.CNPJ = uni.CLINICA_CNPJ;

    JSON_FINAL CLOB;
    TOTAL_COUNT INTEGER;
    CURRENT_ROW INTEGER := 0;
BEGIN
    JSON_FINAL := '[';

    -- Calcula o total de registros
    SELECT COUNT(*) INTO TOTAL_COUNT FROM TB_CLINICA cli JOIN TB_UNIDADE uni ON cli.CNPJ = uni.CLINICA_CNPJ;

    -- Executa o cursor e processa os dados
    FOR i IN TABELAS LOOP
        JSON_FINAL := JSON_FINAL || '{' ||
            CONVERSOR_JSON('CNPJ', i.CNPJ) || ', ' ||
            CONVERSOR_JSON('NOME_CLINICA', i.NOME_CLINICA) || ', ' ||
            CONVERSOR_JSON('END_UNIDADE', i.END_UNIDADE) || ', ' ||
            CONVERSOR_JSON('TIPO_EXAME', i.TIPO_EXAME) ||
        '}';

        -- Incrementa o contador
        CURRENT_ROW := CURRENT_ROW + 1;

        -- Adiciona uma vírgula para separar os itens, exceto no último item
        IF CURRENT_ROW < TOTAL_COUNT THEN
            JSON_FINAL := JSON_FINAL || ',';
        END IF;
    END LOOP;

    JSON_FINAL := JSON_FINAL || ']';

    -- Exibir o resultado JSON
    DBMS_OUTPUT.PUT_LINE(JSON_FINAL);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Nenhum dado encontrado.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro inesperado: ' || SQLERRM);
END;
/

--Procedimento que lê os dados de uma tabela e mostra seus valores anteriores, atuais e próximos.

