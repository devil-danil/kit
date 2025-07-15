# Домашнее задание 8

### Тема лекции
> "Базы данных ч. 1"

### Среда выполнения
> ВМ в YC на Ubuntu 24.04.2 LTS

### Задание

1) Настраиваем себе yc cli по инструкции https://yandex.cloud/ru/docs/cli/quickstart
2) Генерируем пару ssh-ключей, если у вас вдруг нет
3) Заводим себе сеть и сабнеты, после чего создаём себе виртуалку:
yc compute instance create --name <name>  --zone <your zone> --network-interface subnet-name=<your subnet name>,nat-ip-version=ipv4 --create-boot-disk image-id=fd8va75djse9e2ojhoka,type=network-ssd --ssh-key /path/to/.ssh/id_rsa.pub --cores 2 --memory 4GB
4) Заходим туда с использованием приватной части ключа и именем юзера yc-user
5) Запускаем /usr/local/bin/validator
6) Наша задача добиться Ok от validator (он говорит, что ему не нравится, но не очень детально), починив СУБД и не потеряв при этом данные

Сдавать нужно bash history (с объяснением нетривиальных действий и ваших наблюдений, например, зашел в директорию A, посмотрел на файл B, ожидал увидеть C, увидел D, делаю вывод, что это E ...)

Если не удаётся починить до дедлайна, сдавайте то, что есть. Даже минимальное описание того, в чем проблема, потенциально поможет. Представьте, что такое случилось на вашем дежурстве, и вот вы в ночи что-то надиагностировали, придут более опытные коллеги и быстрее починят, если ваш анализ будет точным.

Если всё удалось починить, напишите в несколько предложений ваши предположения о том, как система в это состояние пришла.

### Решение

1. Настраиваю yc cli по инструкции

```bash
yc compute instance create --name vm_dz8  --zone ru-central1-a --network-interface subnet-name=my-yc-subnet-a,nat-ip-version=ipv4 --create-boot-disk image-id=fd8va75djse9e2ojhoka,type=network-ssd --ssh-key /Users/devil_danil/.ssh/id_ed25519.pub --cores 2 --memory 4GB
```

Сталкиваюсь с ошибкой нехватки ресурсов:

![screenshot_1](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_1.jpg)

Одногруппники приходят на помощь, виртуалка создана!

![screenshot_2](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_2.png)

```bash
one_to_one_nat:
        address: 51.250.79.50
        ip_version: IPV4
```

2. Подключаюсь к ВМ

`ssh yc-user@51.250.79.50`

3. Ищу службу PosqgreSQL

![screenshot_3](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_3.png)

4. Проверяю её статус

![screenshot_4](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_4.png)

5. Пробую запустить валидатор

![screenshot_5](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_5.png)

> Сталкиваюсь с ошибкой

6. Проверяю логи службы и смотрю состояние кластеров

![screenshot_6](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_6.png)

> Предполагаю, что либо кластер не инициализировали, либо же дректория смонтирована не туда

7. Останавшиваю службу и перед дальнейшими манипуляциями делаю бекап директории main кластера

`sudo systemctl stop postgresql@16-main`

`sudo -u postgres cp -a /var/lib/postgresql/16/main /var/lib/postgresql/16/main_bkp`

8. Восстановливаю кластер с использованием архива WAL

Использую резервную копию директории main кластера и начинаю восстановление заново, ищу параметры последнего чекпоинта:

```bash
find /var/lib/postgresql/16/main/archive -type f -name "000000*" -exec sh -c '
  for file; do
    echo "Processing file: $file"
    /usr/lib/postgresql/16/bin/pg_waldump "$file"
  done
' sh {} +
```

![screenshot_7](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_7.png)

> В результате нахожу валидный WAL-файл с нужными параметрами — он содержит информацию о чекпоинте, номере следующей транзакции и идентификаторе OID

9. Пробую апустить pg_resetwal, вручную задавая:
- имя следующего сегмента WAL (0000000100000000000000CD)
- номер следующей транзакции (749)
- начальный OID (24576)

![screenshot_8](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_8.png)

> Получаю ошибку из-за отсутсвия файла global/pg_control

9. Пробую генерировать временный кластер через initdb и скопировать pg_control в директорию повреждённого кластера и перезапускаю pg_resetwal

![screenshot_9](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_9.png)

`sudo -u postgres /usr/lib/postgresql/16/bin/pg_resetwal -l 0000000100000000000000CD -x 749 -o 24576 /var/lib/postgresql/16/main`

10. Проверяю состояние кластеров через pg_lsclusters

![screenshot_10](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_10.png)

11. Запускаю повторно валидатор

![screenshot_11](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_11.png)

> Пока что обработка медленная

12. В логах службы нахожу строку с пользователем БД

`2025-07-15 19:35:41.730 UTC [18602] app@appdb FATAL:  terminating connection due to administrator command`

Пробую подключиться к БД

`psql -U app -d appdb`

![screenshot_12](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_12.png)

> Подключение успешно!

13. Проверяю, какие транзакции активны и останавливаю зависшую транзакцию

`select * from pg_stat_activity;`

![screenshot_13](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_13.png)

14. Останавливаю зависшую транзакцию

![screenshot_14](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_14.png)

> Выясняю, что транзакиця запускается опять и блокирует другие

15. Ищу в crontab скрипт запускающий блокирующую транзакцию и закомменчиваю её

![screenshot_15](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_15.png)

16. Удаляю дублированные строки в БД

![screenshot_16](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_16.png)

16. Пересоздаю индекс таблицы

![screenshot_17](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_17.png)

17. Отсоединяюсь от БД и проверяю валидатор

![screenshot_18](https://github.com/devil-danil/kit/blob/main/task-8/screenshots/screen_18.png)

> Всё ОК - ура!

## Вывод

Вероятно, что во время переключения кластера произошёл сбой, либо из-за неверного прерывания транзакции задвоились строки с состоянием 