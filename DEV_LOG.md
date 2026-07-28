# Лог разработки dbt flight_practice

> Справочник разработчика — заметки о том, что узнали и как делали

---

## О проекте

**Проект:** dbt-flight-practice  
**База данных:** PostgreSQL  
**Адаптер:** dbt-postgres 1.9.1  
**Версия dbt:** 1.10.22  
**Виртуальное окружение:** `/Users/andmin/Desktop/DBT/less1/dbt-env`

### Активация виртуального окружения

```bash
source /Users/andmin/Desktop/DBT/less1/dbt-env/bin/activate
```

---

## Структура проекта

```
flight_practice/
├── models/
│   ├── staging/
│   │   └── flight/
│   │       ├── _flight_sources.yml          # Описание источников
│   │       ├── staging_flights__aircraft.sql
│   │       ├── staging_flights__airports.sql
│   │       ├── staging_flights__bookings.sql
│   │       ├── staging_flights__boarding_passes.sql
│   │       ├── staging_flights__flights.sql
│   │       ├── staging_flights__seats.sql
│   │       ├── staging_flights__ticket_flights.sql
│   │       └── staging_flights__tickets.sql
│   └── Intermediate/
│       └── flight/
│           ├── fct_intermediate_flights__bookings.sql
│           ├── fct_intermediate_flights__flights.sql
│           ├── fct_intermediate_flights__ticket_flights.sql
│           └── fct_intermediate_flights__tickets.sql
├── dbt_project.yml
├── profiles.yml
└── DEV_LOG.md                                # Этот файл
```

---

## YAML свойства моделей (properties.yml)

Файл `_int_flights__models.yml` описывает метаданные и конфигурацию моделей intermediate слоя.

### Структура описания модели

```yaml
- name: model_name
    description: Описание модели (поддерживает многострочный текст с |)
    docs:
      show: true                              # Показывать в документации
      node_color: green                       # Цвет в lineage graph
    meta:
      owner: email@example.com                # Владелец модели
      status: in_dev                          # Статус разработки
    columns:
      - name: column_name
        description: Описание колонки
        data_type: datatype                   # Тип данных
        constraints:                          # Ограничения на уровне БД
          - type: not_null
          - type: check
            expression: 'column > 0'
```

### Основные свойства

| Свойство | Назначение | Пример |
|----------|------------|--------|
| `description` | Описание модели/колонки | Многострочный с `|` |
| `docs.show` | Показать в документации | `true/false` |
| `docs.node_color` | Цвет в lineage graph | `red`, `green`, `blue` |
| `meta.owner` | Владелец (email) | `user@example.com` |
| `meta.status` | Статус | `in_dev`, `production` |
| `data_type` | Тип данных | `varchar(10)`, `numeric(10,2)` |
| `constraints` | Ограничения БД | `not_null`, `check`, `unique` |

### Цвета в lineage graph

| Цвет | Назначение |
|------|------------|
| `green` | Production готовые модели |
| `red` | Важные/критические модели |
| `blue` | Стaging модели |
| `yellow` | В разработке |

### Настроенные модели

| Модель | Цвет | Owner | Constraints |
|--------|------|-------|-------------|
| `fct_intermediate_flights__bookings` | red | and1m3n | book_ref: not_null, total_amount: check |
| `fct_intermediate_flights__ticket_flights` | green | and1m3n@example.com | ticket_no: not_null, amount: check |

### Когда проверяется YAML файл

| Команда | Что проверяется |
|---------|-----------------|
| `dbt run` | Читает свойства моделей. Если `contract.enforced: true` — проверяет соответствие колонок и типов данных |
| `dbt test` | Запускает все тесты, указанные в YAML (tests блок) |
| `dbt docs generate` | Генерирует документацию с описаниями, цветами, owner |
| `dbt parse` | Только парсит YAML, проверяет синтаксис без выполнения |

**Важно:** Если YAML невалидный (синтаксическая ошибка) — **любая** команда dbt упадёт на этапе парсинга, до выполнения моделей.

### Примеры ошибок YAML

| Ошибка | Пример | Сообщение |
|--------|--------|-----------|
| Синтаксис | Отступ пробелами вместо табов | `Parsing Error` |
| Неизвестное свойство | `typo:` вместо `type:` | `Unexpected key` |
| Неверный тип | `constraints: "not_null"` вместо списка | `Expected list` |

---

## Intermediate слой

**Назначение:** Промежуточный слой между staging и final/мерами. Используется для объединения данных, простых трансформаций и подготовки данных для аналитики.

### Структура intermediate модели

```sql
{{
  config(
    materialized = 'table'
  )
}}
select col1, col2, col3 from
 {{ ref('staging_flights__table_name') }}
```

**Важно:** Используется `{{ ref() }}` для ссылки на staging модели, а не `{{ source() }}`.

### Созданные intermediate модели

| Модель | Исходная staging модель | Колонки |
|--------|------------------------|----------|
| `fct_intermediate_flights__bookings` | staging_flights__bookings | book_ref, book_date, total_amount |
| `fct_intermediate_flights__flights` | staging_flights__flights | flight_id, flight_no, scheduled_departure, scheduled_arrival, departure_airport, arrival_airport, status, aircraft_code, actual_departure, actual_arrival |
| `fct_intermediate_flights__ticket_flights` | staging_flights__ticket_flights | ticket_no, flight_id, fare_conditions, amount |
| `fct_intermediate_flights__tickets` | staging_flights__tickets | ticket_no, book_ref, passenger_id, passenger_name, contact_data |

### Создание новой intermediate модели

1. Создать SQL файл в `models/Intermediate/flight/`
2. Использовать `{{ ref('staging_flights__source_table') }}` для данных
3. Указать `materialized = 'table'` в config

---

## Источники данных (Sources)

### Подключённые таблицы из `demo_src`:

| Таблица | Описание | Колонки |
|---------|----------|----------|
| `aircrafts` | Самолёты | aircraft_code, model, range |
| `airports` | Аэропорты | airport_code, airport_name, city, coordinates, timezone |
| `seats` | Места в самолёте | aircraft_code, seat_no, fare_conditions |
| `bookings` | Бронирования | book_ref, book_date, total_amount |
| `boarding_passes` | Посадочные талоны | ticket_no, flight_id, boarding_no, seat_no |
| `flights` | Рейсы | flight_id, flight_no, scheduled_departure, scheduled_arrival, departure_airport, arrival_airport, status, aircraft_code, actual_departure, actual_arrival |
| `ticket_flights` | Билеты на рейсы | ticket_no, flight_id, fare_conditions, amount |
| `tickets` | Билеты | ticket_no, book_ref, passenger_id, passenger_name, contact_data |

---

## YAML конфигурация источников

### Базовая структура (dbt 1.10+)

```yaml
sources:
  - name: demo_src
    description: Данные из БД авиаперелетов
    tables:
      - name: table_name
        description: Описание таблицы
        columns:
          - name: column_name
            description: Описание колонки
        config:
          loaded_at_field: timestamp_column
          freshness:
            warn_after:
              count: 24
              period: hour
            error_after:
              count: 48
              period: hour
```

### Важно! Структура для dbt 1.10+

Начиная с версии 1.10, freshness настройки обёрнуты в блок `config:`:

```yaml
tables:
  - name: bookings
    config:                              # ← обязательно для freshness в 1.10+
      loaded_at_field: book_date
      freshness:
        warn_after: {count: 24, period: hour}
        error_after: {count: 48, period: hour}
```

---

## Тесты колонок

### Добавление тестов к колонке

```yaml
columns:
  - name: aircraft_code
    tests:
      - not_null        # ← с подчёркиванием!
      - unique
    description: код самолета
```

**Правильные названия тестов:**
- ✅ `not_null` (с подчёркиванием)
- ✅ `unique`
- ✅ `relationships`
- ❌ `not null` (с пробелом — ошибка!)

---

## Freshness (проверка свежести данных)

### Что это

Проверка того, насколько актуальны данные в источнике. Dbt сравнивает значение в `loaded_at_field` с текущим временем.

### Настройка

```yaml
config:
  loaded_at_field: actual_departure    # Колонка с timestamp
  freshness:
    warn_after:
      count: 24                        # Предупреждение через 24 часа
      period: hour
    error_after:
      count: 48                        # Ошибка через 48 часов
      period: hour
```

### Важно

- В `loaded_at_field` указывается **только имя колонки**, без SQL выражений
- ❌ `loaded_at_field: book_date::timestamp`
- ✅ `loaded_at_field: book_date`

### Проверка

```bash
dbt source freshness
```

---

## Типы материализации в dbt

Материализация определяет, как dbt создаёт или обновляет данные в базе данных.

### Основные типы

| Тип | Описание | Когда использовать |
|-----|----------|-------------------|
| `table` | Создаёт/пересоздаёт таблицу при каждом запуске | Для больших данных, сложных трансформаций, часто используемых моделей |
| `view` | Создаёт представление (виртуальная таблица) | Для простых трансформаций, экономии места на диске |
| `ephemeral` | Не создаёт объект — подставляет SQL как CTE | Для простых шагов, которые не нужно хранить отдельно |
| `incremental` | Добавляет только новые данные | Для растущих таблиц (логи, события) |

### Различия на примере ticket_flights

#### Вариант 1: staging — ephemeral, fct — table

```sql
-- staging_flights__ticket_flights.sql
{{
  config(
    materialized = 'ephemeral'  -- Не создаёт таблицу, только CTE
  )
}}
select ticket_no, flight_id, fare_conditions, amount from
{{ source('demo_src','ticket_flights') }}

-- fct_ticket_flights.sql
{{
  config(
    materialized = 'table'      -- Создаёт физическую таблицу
  )
}}
select * from {{ ref('staging_flights__ticket_flights') }}
```

**Плюсы:** Экономия места на диске (staging не хранится)
**Минусы:** staging SQL подставляется в каждый запрос, может усложнить отладку

---

#### Вариант 2: staging — table, fct — view

```sql
-- staging_flights__ticket_flights.sql
{{
  config(
    materialized = 'table'      -- Создаёт физическую таблицу
  )
}}
select ticket_no, flight_id, fare_conditions, amount from
{{ source('demo_src','ticket_flights') }}

-- fct_ticket_flights.sql
{{
  config(
    materialized = 'view'        -- Создаёт представление
  )
}}
select * from {{ ref('staging_flights__ticket_flights') }}
```

**Плюсы:** staging хранится как таблица (удобно отлаживать), fct не занимает места
**Минусы:** При каждом запросе к fct читается staging таблица

---

#### Вариант 3: staging — table, fct — table

```sql
-- staging_flights__ticket_flights.sql
{{
  config(
    materialized = 'table'      -- Создаёт физическую таблицу
  )
}}
select ticket_no, flight_id, fare_conditions, amount from
{{ source('demo_src','ticket_flights') }}

-- fct_ticket_flights.sql
{{
  config(
    materialized = 'table'      -- Создаёт физическую таблицу
  )
}}
select * from {{ ref('staging_flights__ticket_flights') }}
```

**Плюсы:** Обе модели хранятся отдельно, быстрая работа fct
**Минусы:** Занимает больше места на диске

---

### Сравнение производительности

| Вариант | Место на диске | Скорость запросов | Отладка |
|---------|---------------|-------------------|---------|
| ephemeral → table | ⭐⭐ (меньше) | ⭐⭐ (CTE подставляется) | ⭐ (сложно отлаживать) |
| table → view | ⭐⭐ (1 таблица) | ⭐⭐ (через view) | ⭐⭐⭐ (staging доступен) |
| table → table | ⭐ (2 таблицы) | ⭐⭐⭐ (самая быстрая) | ⭐⭐⭐ (обе доступны) |

### Рекомендации

- **Staging слой:** используйте `table` — удобнее отлаживать и проверять данные
- **Intermediate:** используйте `table` или `view` в зависимости от сложности
- **Ephemeral:** только для очень простых, редко используемых трансформаций

---

## ref() vs source()

| Функция | Для чего используется | Пример |
|---------|----------------------|--------|
| `{{ source('source_name', 'table_name') }}` | Подключение к исходным данным (raw data) | `{{ source('demo_src', 'bookings') }}` |
| `{{ ref('model_name') }}` | Ссылка на другую dbt модель | `{{ ref('staging_flights__bookings') }}` |

**Правило:**
- В **staging** моделях — используйте `source()`
- В **intermediate** и **final** моделях — используйте `ref()`

---

## Полезные команды dbt

```bash
# Активация venv
source /Users/andmin/Desktop/DBT/less1/dbt-env/bin/activate

# Проверка соединения с БД
dbt debug

# Запуск всех моделей
dbt run

# Запуск конкретного слоя
dbt run --select models/Intermediate
dbt run --select models/staging

# Запуск конкретной модели
dbt run --select fct_intermediate_flights__ticket_flights

# Запуск тестов
dbt test

# Проверка свежести источников
dbt source freshness

# Генерация документации
dbt docs generate

# Запуск сервера документации (откроет в браузере)
dbt docs serve

# Очистка кэша
dbt clean
```

### Порядок действий для проверки изменений

1. **dbt run** — создаёт/обновляет модели в базе данных
2. **dbt test** — проверяет все тесты и constraints
3. **dbt docs generate** + **dbt docs serve** — генерирует и открывает документацию для проверки метаданных

---

## Распространённые ошибки и решения

### Ошибка: `'test_not' is undefined`

**Причина:** Неверный синтаксис теста — использован пробел вместо подчёркивания.

**Решение:** Заменить `not null` на `not_null`

---

### Ошибка: `Invalid sources config ... freshness is not valid under any of the given schemas`

**Причина 1:** Версия dbt 1.10+ требует блок `config:`

**Решение:**
```yaml
config:
  loaded_at_field: book_date
  freshness:
    warn_after: {count: 24, period: hour}
```

**Причина 2:** Нереалистичные значения freshness (например, 600000 часов)

**Решение:** Используйте адекватные значения (24-48 часов)

---

### Ошибка: `Could not compute freshness ... no 'loaded_at_field' provided`

**Причина:** Не указан `loaded_at_field` в конфигурации

**Решение:** Добавьте `loaded_at_field: <column_name>` в блок `config:`

---

## Создание новой staging модели

### 1. Создать SQL файл

```sql
{{
  config(
    materialized = 'table'
  )
}}
select col1, col2, col3 from 
{{ source('demo_src','table_name')}}
```

### 2. Добавить описание в sources YAML

```yaml
- name: table_name
  description: Описание таблицы
  columns:
    - name: col1
      description: Описание колонки
```

---

## Источники и дополнительная информация

- [dbt Documentation — Sources](https://docs.getdbt.com/docs/build/sources)
- [dbt Documentation — Freshness](https://docs.getdbt.com/docs/build/sources#checking-source-freshness)
- [dbt Documentation — Tests](https://docs.getdbt.com/docs/build/tests)

---

*Дата создания: 2026-07-23*
*Обновлено: 2026-07-23 — добавлен intermediate слой, свойства моделей (properties.yml)*
