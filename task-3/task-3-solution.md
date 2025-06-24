# Домашнее задание 3

Я запустил в консоли на сервисе важный сервис, но забыл запустить его в фоне… мне надо закрыть ноут и бежать на лекцию….

Важный сервис:

\
#! /usr/bin/bash
while true; do
  echo "`date` I am still alive"
  sleep 1
done

Задача - отвязать процесс от консоли и перенаправить вывод в файл чтобы 1 и 2 дескриптор писали в файлики stdout.txt и stderr.txt

Важное уточнение!!
Сервис нужно запустить из обычной консоли без tmux/screen

предпочтительно это сделать через GDB
другие варианты тоже подойдут

Задание со ✨
Собрать zstd с debug символами самостоятельно
запустить
cat /dev/urandom | zstd -19 -f -T4 -v - -o out.zst
снять с процесса zstd perf record и найти в исходниках zstd самую нагруженную функцию.

### Тема лекции
> "Внутренности Linux"

### Среда выполнения
> macOS 15.5

## Задание
Дан образ машины, в которой перед её выключением было затёрто начало диска, и она теперь не загружается. Пароль пользователя неизвестен. Нужно восстановить работоспособность системы и суметь в неё залогиниться.

## Бонусная часть
Найти и получить секрет.

*Ссылка на архив с образом: https://disk.yandex.ru/d/xwbbmLCWbogOsg*

## Решение основной части
1. Сначала загружаю архив по ссылке

2. Чтобы распаковать файл c zst-расширением устанавливаю zstd

`brew install zstd`

3. Распаковываю архив

`unzstd task2.tar.zst`

4. Теперь распаковываю tar

`tar -xvf task2.tar`

5. Читаю README и пытаюсь запустить скрипт run.sh

`VNCPASSWORD=12345 ./run.sh`

![screenshot_1](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_1.png)

Получаю ошибку из-за отсутствия образа systemrescue-12.01-amd64.iso

6. Загрузим недостающий образ

`curl -L -o systemrescue-12.01-amd64.iso \
  https://download.system-rescue.org/releases/12.01/systemrescue-12.01-amd64.iso`

7. Получу хеш_контрольной_суммы

`curl -L -o systemrescue-12.01-amd64.iso.sha256 \
  https://www.system-rescue.org/releases/12.01/systemrescue-12.01-amd64.iso.sha256`

8. Проверяю целостность образа

`sha256sum --check systemrescue-12.01-amd64.iso.sha256`

![screenshot_2](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_2.png)

> Всё ок!

9. Проверю в другом терминале все TCP-соединения с процессами и отфильтрую по имени процесса qemu

`sudo lsof -iTCP -sTCP:LISTEN -n -P | grep qemu`

-	-iTCP — сетевые TCP-соединения  
-	-sTCP:LISTEN — только слушающие (прослушивающие) порты  
-	-n — не резолвит имена хостов (ускоряет)  
-	-P — показывает порты цифрами (без имен)  

![screenshot_3](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_3.png)

10. Устанавливаю VNC-клиент (TigerVNC) для macOS

`brew install tigervnc`

Запускаю скрипт run.sh
VNCPASSWORD=12345 ./run.sh

11. Запускаю TigerVNC и ввожу данные для подключения к серверу

![screenshot_4](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_4.png)

![screenshot_5](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_5.png)

12. Вижу ошибку при попытке загрузки с диска

![screenshot_6](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_6.png)

![screenshot_7](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_7.png)

13. Захожу в Boot Manager Menu

![screenshot_8](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_8.png)

14. Перехожу к настройкам SecureBoot, отключаю его и перезагружаю систему

![screenshot_9](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_9.png)

15. В меню GRUB выбираю загрузку с параметрами по-умолчанию

![screenshot_10](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_10.png)

16. Видим, что загружена SystemRescue, вошли под root

![screenshot_11](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_11.png)

17. Далее проверим настройки для подключения по ssh

> Посмотрим, какие юнит-файлы доступны в systemd (поищем для служб ssh и firewall)

`systemctl list-unit-files | grep -E 'ssh|fire'`

![screenshot_12](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_12.png)

18. Проверяю состояние ssh-сервера

`systemctl status sshd`

![screenshot_13](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_13.png)

19. Проверяю правила iptables и добавляю правило для SSH

`iptables -L`

![screenshot_14](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_14.png)

`iptables -I INPUT -p tcp --dport 22 -j ACCEPT`

`iptables -L INPUT`

![screenshot_15](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_15.png)

20. С помощью **passwd** меняю пароль для root пользователя

![screenshot_16](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_16.png)

21. Подключаюсь к ВМ по ssh по 2222 порту

![screenshot_17](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_17.png)

22. Смотрю информацию о дисках

`lsblk -f`

![screenshot_18](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_18.png)

> /dev/sda - проблемный диск

23. Проверяю таблицу разделов

`gdisk -l /dev/sda`

![screenshot_19](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_19.png)

> Вижу, что основная таблица повреждена, но резервная копия уцелела

24. Перехожу к восстановлению таблицы разделов

`gdisk /dev/sda`

25. Последовательно выбираю следующие пункты:
- 1 - Use current GPT
- r - recovery and transformation options (experts only)
- c- load backup partition table from disk (rebuilding main)
- Y - подтверждаю изменения
- v - verify disk

![screenshot_20](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_20.png)

- p - print the partition table

![screenshot_21](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_21.png)

- w - write table to disk and exit
- Y - подтверждаю изменения

26. Смотрю информацию о /dev/sda

`lsblk -f /dev/sda`

![screenshot_22](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_22.png)

-	/dev/sda1 — EFI / boot-раздел (VFAT)
-	/dev/sda2 — корневая файловая система (ext4)
-	/dev/sda3 — шифрованный контейнер LUKS
-	/dev/sda4 — физический том LVM, внутри логические тома lv_home и lv_var

27. Провожу диагностику загрузочного раздела без правки данных

`fsck -n /dev/sda1`

![screenshot_23](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_23.png)

- differences between boot sector and its backup

> Основной загрузочный сектор (BPB) отличается от резервного. Обычно не критично: fsck может скопировать резервную копию на место основного

- FSINFO sector has bad magic number(s)

> Повреждён служебный сектор FSINFO: в нём хранятся счётчики свободных кластеров

- Both FATs appear to be corrupt

> Обе таблицы FAT имеют ошибки. Если хотя бы одна цела, fsck сможет восстановить вторую

28. Форматирую и размечаю ESP

`mkfs.vfat -F32 -n EFI /dev/sda1`

> Заново создаю EFI-раздел и помечаю его этикеткой EFI

29. Монтирую корневой и загрузочный разделы с жёсткого диска к ФС

`mount /dev/sda2 /mnt`

`mount /dev/sda1 /mnt/boot/efi`

`for d in proc sys dev; do mount --bind /$d /mnt/$d; done`

30. Проверяю монтирование

`ls -l /mnt`

![screenshot_24](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_24.png)

31. Перехожу в chroot в собранной ФС

`chroot /mnt /bin/bash`

32. Проверяю, что sda1 смонтирован как /boot/efi, а UUID и тип файловой системы у каждого раздела корректные

`lsblk -f /dev/sda`

![screenshot_25](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_25.png)

33. Считывает метаданные раздела /dev/sda1, чтобы знать точный новый UUID/EFI-метку ESP после форматирования

`blkid /dev/sda1`

![screenshot_26](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_26.png)

34. Смотрю содержимое таблицы монтирования и сравниваю текущие записи /boot/efi (или /boot) с тем, что показывает blkid

`cat /etc/fstab`

![screenshot_27](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_27.png)

35. Исправляю содержимое /etc/fstab - меняю старый UUID на новый

`vim /etc/fstab`

`grep vfat /etc/fstab`

`blkid /dev/sda1`

![screenshot_28](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_28.png)

> Теперь UUID и тип файловой системы у каждого раздела корректные

36. Устанавливаю GRUB

`grub-install /dev/sda`

![screenshot_29](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_29.png)

37. Выхожу из chroot и размонтирую ФС

`exit`

`umount -R /mnt`

`mount | grep /mnt`

![screenshot_30](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_30.png)

38. Перезагружаю систему

Ввожу в мониторе QEMU

`system_reset`

Включаю SecureBoot в Boot Manager Menu

![screenshot_31](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_31.png)

> Войти в систему не удается, так как не знаю пароля

39. Перезапускаю ВМ и пробую запустить меню GRUB

![screenshot_32](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_32.png)

40. Чиню запуск меню GRUB

> Прошивка успешно запускает grubx64.efi, но тот скорее всего не знает, где его конфигурация

В открывшемся приглашении grub> пробую:

`ls`

> Если модуль normal действительно лежит на корневом разделе (hd0,gpt2 = /dev/sda2), можно вручную поднять меню

`set root=(hd0,gpt2)`

`set prefix=(hd0,gpt2)/boot/grub`

`insmod normal`

`normal`

Меню появилось!

> Значит, grub.cfg есть, просто GRUB не смог до него «дотянуться» из-за неверных переменных

![screenshot_33](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_33.png)

41. Редактирую параметры ядра

> Нажимаю 'e', заменяю ro на rw init=/bin/bash и загружаю систему (f10)

![screenshot_34](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_34.png)

42. Проверяю всех пользователей

`cat /etc/passwd`

![screenshot_35](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_35.png)

> Необходимо залогиниться под пользователем kit

43. Меняю пароль у пользователя kit

`passwd kit`

![screenshot_36](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_36.png)

44. Перезагружаю систему

`reboot -f`

45. Система успешно загрузилась, пробую авторизоваться под пользователем kit

![screenshot_37](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_37.png)

46. Проверяю, что Secure Boot действительно активирован, и что смонтированы все ФС, перечисленные в оригинальном fstab

`mokutil --sb-state`

`lsblk -f`

`cat /etc/fstab`

![screenshot_38](https://github.com/devil-danil/task-2/blob/main/screenshots/screenshot_38.png)
