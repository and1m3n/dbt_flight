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
│   └── staging/
│       └── flight/
│           ├── _flight_sources.yml          # Описание источников
│           ├── staging_flights__aircraft.sql
│           ├── staging_flights__airports.sql
│           ├── staging_flights__bookings.sql
│           ├── staging_flights__boarding_passes.sql
│           ├── staging_flights__flights.sql
│           ├── staging_flights__seats.sql
│           ├── staging_flights__ticket_flights.sql
│           └── staging_flights__tickets.sql
├── dbt_project.yml
├── profiles.yml
└── DEV_LOG.md                                # Этот файл
```

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

## Полезные команды dbt

```bash
# Активация venv
source /Users/andmin/Desktop/DBT/less1/dbt-env/bin/activate

# Проверка соединения
dbt debug

# Генерация документации
dbt docs generate

# Запуск моделей
dbt run

# Запуск тестов
dbt test

# Проверка свежести источников
dbt source freshness

# Очистка кэша
dbt clean
```

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
*Обновлено: по мере разработки*
