--Sprint 3

set serveroutput on;
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

    NOME_USUARIO := SYS_CONTEXT('USERENV', 'SESSION_USER');
    
    IF INSERTING OR UPDATING THEN
        INSERT INTO TB_PACIENTE_AUDITORIA
            (CPF, NOME_COMPLETO, DATA_NASC, END_PACIENTE, TEL_PACIENTE, 
             EMAIL_PACIENTE, SENHA, SEXO, USUARIO, OPERACAO, DATA_OPERACAO)
        VALUES
            (:NEW.CPF, :NEW.NOME_COMPLETO, :NEW.DATA_NASC, :NEW.END_PACIENTE, :NEW.TEL_PACIENTE, 
             :NEW.EMAIL_PACIENTE, :NEW.SENHA, :NEW.SEXO, NOME_USUARIO, OPERACAO, SYSDATE);
    END IF;

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

    IF VALOR IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Valor nulo não permitido.');
    END IF;

    IF LENGTH(VALOR) > 100 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Valor excede o tamanho máximo permitido.');
    END IF;

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

--Função que substitui uma procedure já existente
//Professor, como já comentei com o senhor todas as procedures que fiz até aqui para 
//nosso projeto eram um CRUD nas tabelas e o que fazia as verificações de cpf
//válidos ou outros já eram todos funções.


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
    JSON_FINAL := '[' || CHR(10); 

    SELECT COUNT(*) INTO TOTAL_COUNT FROM TB_CLINICA cli JOIN TB_UNIDADE uni ON cli.CNPJ = uni.CLINICA_CNPJ;

    FOR i IN TABELAS LOOP
        JSON_FINAL := JSON_FINAL || '{' || CHR(10) ||  
            '    ' || CONVERSOR_JSON('CNPJ', i.CNPJ) || ',' || CHR(10) || 
            '    ' || CONVERSOR_JSON('NOME_CLINICA', i.NOME_CLINICA) || ',' || CHR(10) ||
            '    ' || CONVERSOR_JSON('END_UNIDADE', i.END_UNIDADE) || ',' || CHR(10) ||
            '    ' || CONVERSOR_JSON('TIPO_EXAME', i.TIPO_EXAME) || CHR(10) ||  
        '}';

        CURRENT_ROW := CURRENT_ROW + 1;

        IF CURRENT_ROW < TOTAL_COUNT THEN
            JSON_FINAL := JSON_FINAL || ',' || CHR(10);  
        END IF;
    END LOOP;

    JSON_FINAL := JSON_FINAL || CHR(10) || ']';  

    DBMS_OUTPUT.PUT_LINE(JSON_FINAL);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Nenhum dado encontrado.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro inesperado: ' || SQLERRM);
END;
/


--Procedimento que lê os dados de uma tabela e mostra seus valores como relatório.
CREATE OR REPLACE PROCEDURE RELATORIO_CONSULTAS (
    CURSOR_RETORNO OUT SYS_REFCURSOR)
AS
BEGIN
    OPEN CURSOR_RETORNO FOR
        SELECT 
            p.NOME_COMPLETO AS NomePaciente,
            m.NOME_MED AS NomeMedico,
            cl.NOME_CLINICA AS Clinica,
            u.END_UNIDADE AS Endereco,
            c.DATA_HORA_CONSULTAS AS DataConsulta
        FROM 
            TB_AGENDAMENTO a
        JOIN 
            TB_PACIENTE p ON a.PACIENTE_CPF = p.CPF
        JOIN 
            TB_UNIDADE u ON a.UNIDADE_ID_UNIDADE = u.ID_UNIDADE
        JOIN 
            TB_CLINICA cl ON u.CLINICA_CNPJ = cl.CNPJ
        JOIN 
            TB_MEDICO m ON a.N_PROTOCOLO = m.AGENDAMENTO_N_PROTOCOLO
        JOIN 
            TB_CONSULTAS c ON a.N_PROTOCOLO = c.AGENDAMENTO_N_PROTOCOLO;
        
        EXCEPTION

        WHEN INVALID_CURSOR THEN
            DBMS_OUTPUT.PUT_LINE('Erro: Tentativa de operar com um cursor inválido.');
    
        WHEN TOO_MANY_ROWS THEN
            DBMS_OUTPUT.PUT_LINE('Erro: A consulta retornou mais de uma linha quando apenas uma era esperada.');
    
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Erro inesperado: ' || SQLERRM);
END;

--Para executar a procedure RELATORIO_CONSULTAS já que ela tem um cursor
DECLARE
    cur SYS_REFCURSOR;
    NomePaciente TB_PACIENTE.NOME_COMPLETO%TYPE;
    NomeMedico TB_MEDICO.NOME_MED%TYPE;
    Clinica TB_CLINICA.NOME_CLINICA%TYPE;
    Endereco TB_UNIDADE.END_UNIDADE%TYPE;
    DataConsulta TB_CONSULTAS.DATA_HORA_CONSULTAS%TYPE;
BEGIN
    RELATORIO_CONSULTAS(cur);

    LOOP
        FETCH cur INTO NomePaciente, NomeMedico, Clinica, Endereco, DataConsulta;
        EXIT WHEN cur%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE('Paciente: ' || NomePaciente || ', Médico: ' || NomeMedico ||
                             ', Clínica: ' || Clinica || ', Endereço: ' || Endereco ||
                             ', Data: ' || DataConsulta);
        DBMS_OUTPUT.PUT_LINE(CHR(10));
    END LOOP;

    CLOSE cur;
END;

