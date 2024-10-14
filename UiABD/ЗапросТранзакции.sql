DO $$
DECLARE
    sender_balance NUMERIC;  
BEGIN
    SELECT balacnce::NUMERIC INTO sender_balance
    FROM chet
    WHERE id_chet = 1  -- номер счета отправителя
    FOR UPDATE;

    --  проверить, достаточно ли средств
    IF sender_balance < 100 THEN -- если суима меньше 100
        RAISE EXCEPTION 'Недостаточно средств на счете отправителя';
    END IF;

    -- Ссписать деньги с баланса отправителя
    UPDATE chet
    SET balacnce = balacnce::NUMERIC - 100  --  сумма перевода
    WHERE id_chet = 1;  -- номер счета отправителя

    -- зчислить деньги на счет получателя
    UPDATE chet
    SET balacnce = balacnce::NUMERIC + 100  
    WHERE id_chet = 2;
    -- записать транзакции в историю
    INSERT INTO tranzhak (id_tranzhak, id_chet, data_tranzak, summa, type_tran)
    VALUES (19,1, NOW(), 100, 'Списание со счета');

    INSERT INTO tranzhak (id_tranzhak , id_chet, data_tranzak, summa, type_tran)
    VALUES (20,2, NOW(), 100, 'Зачисление на счет');

    -- если успешно, транзакция завершится автоматически
EXCEPTION
    -- обработать ошибки, если что-то пойдет не так
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка при переводе денег: ', SQLERRM;
        ROLLBACK;
END $$;
--------------------------------------------------------------------
-- Установим уровень изоляции для обеих транзакций на READ COMMITTED (по умолчанию в PostgreSQL)

-- Транзакция клиента 1
BEGIN;  -- Начало транзакции клиента 1
-- Чтение баланса счета клиента 1
SELECT balacnce 
FROM chet
WHERE id_chet = 1;  -- замените на нужный id счета клиента 1

-- Транзакция клиента 2
BEGIN;  -- Начало транзакции клиента 2
-- Клиент 2 переводит деньги на счет клиента 1
UPDATE chet
SET balacnce = balacnce - 500 -- уменьшаем баланс клиента 2 (замените на нужную сумму)
WHERE id_chet = 2;  -- замените на нужный id счета клиента 2

-- Увеличиваем баланс клиента 1
UPDATE chet
SET balacnce = balacnce + 500 -- увеличиваем баланс клиента 1
WHERE id_chet = 1;  -- замените на нужный id счета клиента 1

-- Фиксируем транзакцию клиента 2
COMMIT;

-- Клиент 1 снова читает баланс своего счета
SELECT balacnce 
FROM chet
WHERE id_chet = 1;  -- замените на нужный id счета клиента 1

-- Фиксируем транзакцию клиента 1
COMMIT;


---------------------------------------------------
-- Клиент 2 начинает транзакцию
BEGIN TRANSACTION;

-- Клиент 2 снимает деньги со своего счета (например, id_chet = 2)
UPDATE chet 
SET balacnce = balacnce::NUMERIC - 500 
WHERE id_chet = 2;

-- Клиент 2 добавляет деньги на счет клиента 1 (например, id_chet = 1)
UPDATE chet 
SET balacnce = balacnce::NUMERIC + 500 
WHERE id_chet = 1;

-- Фиксируем транзакцию клиента 2
COMMIT;
-- Клиент 1 начинает транзакцию
BEGIN TRANSACTION;

-- Устанавливаем уровень изоляции REPEATABLE READ
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Клиент 1 читает баланс своего счета (например, id_chet = 1)
SELECT balacnce 
FROM chet 
WHERE id_chet = 1;

-- На этом этапе баланс клиента 1 будет прежним, до изменений клиента 2

-- Если клиент 1 снова читает баланс счета:
SELECT balacnce 
FROM chet 
WHERE id_chet = 1;

-- Баланс останется таким же, несмотря на изменения клиента 2, до завершения транзакции клиента 1

-- Завершение транзакции клиента 1
COMMIT;

-------------------------------------
-- Клиент 1 начинает транзакцию
BEGIN TRANSACTION;

-- Устанавливаем уровень изоляции SERIALIZABLE
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Клиент 1 читает баланс своего счета (например, id_chet = 1)
SELECT balacnce FROM chet WHERE id_chet = 1;

-- Клиент 1 переводит 500 единиц со своего счета (id_chet = 1) на счет клиента 3 (id_chet = 3)
UPDATE chet SET balacnce = balacnce::NUMERIC - 500 WHERE id_chet = 1;
UPDATE chet SET balacnce = balacnce::NUMERIC + 500 WHERE id_chet = 3;

-- Клиент 1 пытается завершить транзакцию
COMMIT;
-- Клиент 2 начинает транзакцию
BEGIN TRANSACTION;

-- Устанавливаем уровень изоляции SERIALIZABLE
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Клиент 2 читает баланс своего счета (например, id_chet = 2)
SELECT balacnce FROM chet WHERE id_chet = 2;

-- Клиент 2 переводит 300 единиц со своего счета (id_chet = 2) на счет клиента 3 (id_chet = 3)
UPDATE chet SET balacnce = balacnce::NUMERIC - 300 WHERE id_chet = 2;
UPDATE chet SET balacnce = balacnce::NUMERIC + 300 WHERE id_chet = 3;

-- Клиент 2 пытается завершить транзакцию
COMMIT;


---------------------------------------------------------------
BEGIN;

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

-- Чтение информации о транзакции с ID=1
SELECT * FROM tranzhak WHERE id_tranzhak = 1;

-- В другом сеансе
-- 5. Клиент 2 начинает транзакцию
BEGIN;

-- Изменение суммы транзакции с ID=1
UPDATE tranzhak SET summa = 200 WHERE id_tranzhak = 1;

-- 6. Фиксация транзакции для клиента 2
COMMIT;

-- 7. Клиент 1 снова читает информацию о транзакции с ID=1
SELECT * FROM tranzhak WHERE id_tranzhak = 1;

-- Завершение транзакции для клиента 1
COMMIT;
_-----------------------------------------------------------------
-- Сессия клиента 1
BEGIN;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Чтение информации о транзакции с ID=1
SELECT * FROM tranzhak WHERE id_tranzhak = 1;
-- Сессия клиента 2
BEGIN;

-- Изменение суммы транзакции с ID=1
UPDATE tranzhak SET summa = 200 WHERE id_tranzhak = 1;

-- Фиксация транзакции для клиента 2
COMMIT;
-- Сессия клиента 1 снова читает
SELECT * FROM tranzhak WHERE id_tranzhak = 1;

-- Завершение транзакции для клиента 1
COMMIT;
----------------------------------------------------------
-- Сессия клиента 1
BEGIN;

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Чтение информации о транзакции с ID=1
SELECT * FROM tranzhak WHERE id_tranzhak = 1;
-- Сессия клиента 2
BEGIN;

-- Изменение суммы транзакции с ID=1
UPDATE tranzhak SET summa = 200 WHERE id_tranzhak = 1;

-- Фиксация транзакции для клиента 2
COMMIT;
-- Сессия клиента 1 снова читает
SELECT * FROM tranzhak WHERE id_tranzhak = 1;

-- Завершение транзакции для клиента 1
COMMIT;
--------------------------------------------------
-- Сессия клиента 1
BEGIN;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Попытка изменить сумму транзакции с ID=1
UPDATE tranzhak SET summa = 1000 WHERE id_tranzhak = 1;

-- Фиксация транзакции для клиента 1
COMMIT;
-- Сессия клиента 2
BEGIN;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Попытка изменить сумму транзакции с ID=1
UPDATE tranzhak SET summa = 1500 WHERE id_tranzhak = 1;

-- Фиксация транзакции для клиента 2
COMMIT;

-------------------------------------------------------------------
-- Сессия клиента 2
BEGIN;

-- Добавление нового кредита
INSERT INTO kredit (id_kredit, id_chet, summa, prochent_stavki, srok_kredita) VALUES 
(12, 1, 3000, 12, 36);

-- Фиксация транзакции
COMMIT;
-- Сессия клиента 1 снова
SELECT * FROM kredit;

-- Завершение транзакции
COMMIT;
-------------------------------------------------------
-- Сессия клиента 1
BEGIN;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Чтение информации о кредитах
SELECT * FROM kredit;

-- Не завершаем транзакцию, чтобы она оставалась открытой
-- Эта сессия будет ожидать завершения второй сессии

-- Сессия клиента 2
BEGIN;

-- Добавление нового кредита
INSERT INTO kredit (id_kredit, id_chet, summa, prochent_stavki, srok_kredita) VALUES 
(3, 1, 3000, 12, 36);

-- Фиксация транзакции
COMMIT;
-- Сессия клиента 1 снова
SELECT * FROM kredit;

-- Завершение транзакции
COMMIT;

