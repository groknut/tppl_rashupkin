# Полный подробный разбор `avgdiff.asm`

Ниже — учебный разбор всей программы: сначала архитектура x86-64 и регистры, потом каждая инструкция, потом полный разбор кода.

---

# Часть 1. Архитектура x86-64 и регистры

## 1.1. Регистры общего назначения

В x86-64 есть 16 регистров общего назначения по 64 бита:

| 64-бит | 32-бит | 16-бит | 8-бит (младший) | 8-бит (старший) |
|---|---|---|---|---|
| `rax` | `eax` | `ax` | `al` | `ah` |
| `rbx` | `ebx` | `bx` | `bl` | `bh` |
| `rcx` | `ecx` | `cx` | `cl` | `ch` |
| `rdx` | `edx` | `dx` | `dl` | `dh` |
| `rsi` | `esi` | `si` | `sil` | — |
| `rdi` | `edi` | `di` | `dil` | — |
| `rbp` | `ebp` | `bp` | `bpl` | — |
| `rsp` | `esp` | `sp` | `spl` | — |
| `r8` | `r8d` | `r8w` | `r8b` | — |
| `r9` | `r9d` | `r9w` | `r9b` | — |
| `r10` | `r10d` | `r10w` | `r10b` | — |
| `r11` | `r11d` | `r11w` | `r11b` | — |
| `r12` | `r12d` | `r12w` | `r12b` | — |
| `r13` | `r13d` | `r13w` | `r13b` | — |
| `r14` | `r14d` | `r14w` | `r14b` | — |
| `r15` | `r15d` | `r15w` | `r15b` | — |

**Важно:** все эти имена — это **одни и те же физические регистры**, просто разные «окна» на их биты.

Например, `rax` — это 64-битное окно. Если записать в `eax`, то младшие 32 бита `rax` обнулятся, а старшие 32 — обнулятся тоже (это специфика x86-64: запись в 32-битный регистр обнуляет старшие 32 бита). Если записать в `al`, изменится только младший байт, а остальные 7 байт `rax` **не изменятся**.

Пример:

```asm
mov rax, 0x1122334455667788
mov al, 0xAA               ; rax = 0x11223344556677AA
mov ax, 0xBBBB             ; rax = 0x112233445566BBBB
mov eax, 0xCCCCCCCC        ; rax = 0x00000000CCCCCCCC (старшие 32 бита обнулились)
```

## 1.2. Регистры специального назначения

- `rsp` — указатель стека (Stack Pointer). Указывает на вершину стека.
- `rbp` — указатель базы кадра (Base Pointer). Обычно не обязателен.
- `rip` — указатель инструкции (Instruction Pointer). Нельзя изменять напрямую.
- `rflags` — регистр флагов. Хранит результаты сравнений (`ZF`, `SF`, `CF`, `OF` и т.д.).

## 1.3. Что значат суффиксы в именах

- `r` в начале (`rax`, `rbx`...) — 64 бита;
- `e` в начале (`eax`, `ebx`...) — 32 бита (extended);
- без префикса с `x` в конце (`ax`, `bx`...) — 16 бит;
- `l` в конце (`al`, `bl`...) — младшие 8 бит;
- `h` в конце (`ah`, `bh`...) — старшие 8 бит (только для rax..rdx);
- `d` в конце (`r8d`...`r15d`) — 32 бита;
- `w` в конце (`r8w`...`r15w`) — 16 бит;
- `b` в конце (`r8b`...`r15b`) — 8 бит.

## 1.4. Системные вызовы Linux x86-64

Соглашение о вызове:

- номер syscall → `rax`;
- аргументы → `rdi`, `rsi`, `rdx`, `r10`, `r8`, `r9` (в этом порядке);
- инструкция `syscall`;
- результат → `rax`.

Замечание: `rcx` и `r11` **портятся** ядром при `syscall`.

Основные используемые syscall:

| Номер | Имя | Аргументы |
|---|---|---|
| 0 | `read` | `rdi=fd, rsi=buf, rdx=len` |
| 1 | `write` | `rdi=fd, rsi=buf, rdx=len` |
| 2 | `open` | `rdi=path, rsi=flags, rdx=mode` |
| 60 | `exit` | `rdi=code` |

---

# Часть 2. Все инструкции, встречающиеся в коде

## 2.1. Пересылка данных

### `mov`

Копирует значение из источника в приёмник. **Не меняет флаги**.

```asm
mov rdi, %1        ; загрузить адрес пути в rdi
mov eax, 1         ; загрузить число 1 в eax
mov byte [rdi], 10 ; записать байт 10 по адресу rdi
```

Формы:

```asm
mov reg, reg
mov reg, imm          ; immediate (число)
mov reg, [mem]        ; из памяти
mov [mem], reg        ; в память
movzx reg, reg8/16    ; с расширением нулями
```

### `lea` (Load Effective Address)

Вычисляет адрес и кладёт его в регистр, **не читая память**.

```asm
lea rsi, [rel buffer]       ; rsi = адрес buffer
lea rdx, [rel outbuf + 64]  ; rdx = outbuf + 64
```

`rel` — относительная адресация (position-independent code). Важно в 64-битных программах без PIE-флага.

### `movzx` (Move with Zero-Extend)

Копирует меньший регистр в больший, заполняя старшие биты нулями.

```asm
movzx rdx, al      ; rdx = al (0..255), старшие биты rdx = 0
```

### `cqo` (Convert Quadword to Octaword)

Расширяет знак `rax` в `rdx:rax`. Если `rax >= 0`, то `rdx = 0`; если `rax < 0`, то `rdx = -1` (все единицы).

```asm
cqo                ; rdx:rax = знаковое расширение rax
```

Нужно перед `idiv` для знакового деления 128-битного делимого.

## 2.2. Арифметика

### `add`

```asm
add r8, rdx        ; r8 = r8 + rdx
add r14, rax       ; r14 = r14 + rax
```

Меняет флаги (`ZF`, `SF`, `CF`, `OF`).

### `sub`

```asm
sub al, '0'        ; al = al - 48
sub rax, r8        ; rax = rax - r8
sub rdx, r12       ; rdx = rdx - r12
```

Меняет флаги.

### `inc`

```asm
inc rsi            ; rsi = rsi + 1
inc r13            ; r13 = r13 + 1
```

**Не меняет** флаг `CF`. Меняет остальные (`ZF`, `SF`, `OF`).

### `dec`

```asm
dec rcx            ; rcx = rcx - 1
dec rdi            ; rdi = rdi - 1
```

### `neg`

Меняет знак числа (двумя дополнениями).

```asm
neg r8             ; r8 = -r8
neg rax            ; rax = -rax
```

### `imul` (Signed Multiply)

```asm
imul r8, r8, 10    ; r8 = r8 * 10
```

Трёхаргументная форма: `imul dest, src, imm`. Умножает `src` на `imm`, результат в `dest`.

### `div` (Unsigned Divide)

Делит `rdx:rax` на операнд. Результат — в `rax`, остаток — в `rdx`.

```asm
div rbx            ; rax = (rdx:rax) / rbx, rdx = остаток
```

**Перед `div` нужно обнулить `rdx`**, иначе получится деление на мусор.

### `idiv` (Signed Divide)

То же самое, но знаковое.

```asm
cqo                ; расширить знак rax в rdx
idiv rcx           ; rax = (rdx:rax) / rcx знаково
```

Перед `idiv` нужно сделать `cqo`, чтобы `rdx:rax` правильно представляло знаковое число.

## 2.3. Логика и сравнение

### `xor`

Побитовое исключающее ИЛИ. Часто используется как быстрый способ обнулить регистр:

```asm
xor esi, esi       ; esi = 0 (и быстрее, и короче чем mov esi, 0)
xor r8, r8         ; r8 = 0
xor edx, edx       ; edx = 0
```

Обнуляет флаги (`ZF = 1`), но это обычно неважно.

### `test`

Побитовое И, **но результат не сохраняется** — только устанавливаются флаги.

```asm
test rax, rax      ; проверка: rax == 0 ?
test r9d, r9d      ; r9d == 0 ?
test r12, r12      ; r12 == 0 ?
```

Если `rax == 0`, то `ZF = 1`. Если `rax < 0`, то `SF = 1`.

### `cmp`

Вычитает второй операнд из первого и устанавливает флаги, но результат никуда не сохраняет.

```asm
cmp qword [rsp], 2 ; проверка: [rsp] == 2
cmp al, '0'        ; al == '0' ?
cmp r12, r13       ; r12 == r13 ?
cmp r13, 128       ; r13 < 128 ? (по флагам)
```

## 2.4. Переходы

Все условные переходы зависят от флагов после `cmp` или `test`.

| Инструкция | Условие | Смысл |
|---|---|---|
| `je` / `jz` | `ZF = 1` | равно / равно нулю |
| `jne` / `jnz` | `ZF = 0` | не равно / не ноль |
| `jb` | `CF = 1` | беззнаковое меньше |
| `jae` | `CF = 0` | беззнаковое больше-или-равно |
| `ja` | `CF = 0 и ZF = 0` | беззнаковое больше |
| `js` | `SF = 1` | знак минус (отрицательное) |
| `jns` | `SF = 0` | знак плюс |
| `jmp` | — | безусловный переход |

Примеры из кода:

```asm
jne .error         ; если не равно — перейти на .error
jae .error         ; если беззнаково >= — перейти на .error
js .error          ; если отрицательное — перейти на .error
jz .end_of_file    ; если ноль — перейти на .end_of_file
```

## 2.5. Директивы NASM

### `section`

Задаёт секцию.

```asm
section .bss       ; неинициализированные данные
section .data      ; инициализированные данные
section .text      ; код
```

### `global`

Делает метку видимой для линкера.

```asm
global _start
```

### `resb`, `resq`

Резервируют место в `.bss`.

```asm
buffer resb 1024   ; 1024 байта
bytes_read resq 1  ; 1 quadword (8 байт)
```

### `db`

Define Byte — задаёт байты в памяти.

```asm
prefix db "filename: "
```

### `equ`

Присваивает константе выражение.

```asm
prefix_len equ $ - prefix
```

`$` — текущий адрес, `prefix` — адрес начала строки. Разность = длина.

### `%macro ... %endmacro`

Определяет макрос.

```asm
%macro WRITE 2
    ...
%endmacro
```

Параметры обозначаются `%1`, `%2`.

### Локальные метки в макросе

`%%label` — уникальная метка внутри макроса. При каждом раскрытии макроса она получает своё имя, чтобы не конфликтовать при повторном использовании.

---

# Часть 3. Полный разбор кода построчно

## 3.1. Шапка

```asm
; Читает файл с двумя строками чисел, считает среднее от (x[i] - y[i]).
```

Просто комментарий.

## 3.2. Макрос `WRITE`

```asm
%macro WRITE 2                    ; объявление макроса с двумя параметрами
    mov eax, 1                    ; rax = 1, номер syscall write
    mov edi, 1                    ; rdi = 1, дескриптор stdout
    mov rsi, %1                   ; rsi = адрес буфера (первый параметр)
    mov edx, %2                   ; rdx = длина (второй параметр)
    syscall                       ; вызов ядра
%endmacro                         ; конец макроса
```

Раскрытие `WRITE prefix, prefix_len` даёт:

```asm
mov eax, 1
mov edi, 1
mov rsi, prefix
mov edx, prefix_len
syscall
```

Пишет `prefix_len` байт из `prefix` в stdout.

## 3.3. Макрос `EXIT`

```asm
%macro EXIT 1                     ; один параметр — код возврата
    mov eax, 60                   ; syscall exit
    mov edi, %1                   ; код возврата в rdi
    syscall                       ; вызов ядра
%endmacro
```

## 3.4. Макрос `OPEN`

```asm
%macro OPEN 1
    mov rdi, %1                   ; путь к файлу (argv[1])
    xor esi, esi                  ; flags = 0 = O_RDONLY
    xor edx, edx                  ; mode = 0
    mov eax, 2                    ; syscall open
    syscall
%endmacro
```

`xor esi, esi` обнуляет `esi` (и заодно сбрасывает флаги, но это неважно). После открытия в `rax` — файловый дескриптор (неотрицательное число) или отрицательный код ошибки.

## 3.5. Макрос `READ`

```asm
%macro READ 3                     ; три параметра: fd, buf, size
    mov rdi, %1                   ; fd
    mov rsi, %2                   ; буфер
    mov edx, %3                   ; размер
    xor eax, eax                  ; syscall read = 0
    syscall
%endmacro
```

## 3.6. Макрос `ARRAY`

```asm
%macro ARRAY 2
    %1 resq %2                    ; "имя resq количество"
%endmacro
```

`ARRAY x_values, 128` раскрывается в `x_values resq 128`. Это резервирует 128 * 8 = 1024 байта под метку `x_values`.

## 3.7. Макрос `ADD_DIGIT`

```asm
%macro ADD_DIGIT 0                ; без параметров
    sub al, '0'                   ; ASCII -> значение 0..9
    imul r8, r8, 10               ; r8 *= 10
    movzx rdx, al                 ; rdx = al (0..9)
    add r8, rdx                   ; r8 += rdx
    mov r9d, 1                    ; флаг «видели цифру»
%endmacro
```

Здесь `al` — 8 бит `rax`, где лежит текущий символ (после `mov al, [rsi]`). `'0'` в NASM — это код символа 48.

## 3.8. Макрос `ADD_NUMBER`

Разбираем по ветвям:

```asm
%macro ADD_NUMBER 0
    test r9d, r9d                 ; были ли цифры?
    jz %%no_number                ; если нет — выходим
```

Если `r9d == 0`, число не собиралось (например, был один минус или разделитель), ничего не делаем.

```asm
    test r10d, r10d               ; был ли минус?
    jz %%positive                 ; если нет — оставляем как есть
    neg r8                        ; если да — r8 = -r8
%%positive:
```

```asm
    cmp r11d, 0                   ; первая строка?
    jne %%second_row
```

`r11d` — текущий «номер строки»: 0 = первая, 1 = вторая, 2 = после второй.

**Ветка первой строки:**

```asm
    cmp r13, 128                  ; не переполнен ли массив?
    jae .error                    ; если r13 >= 128 — ошибка
    mov [x_values + r13*8], r8    ; x_values[r13] = r8
    inc r13                       ; счётчик x++
    jmp %%reset
```

`[x_values + r13*8]` — это адрес `x_values + r13 * 8`. Так как каждый элемент — 8 байт (`resq`), умножаем индекс на 8. В NASM можно писать именно так: `[base + index*scale]`.

**Ветка второй строки:**

```asm
%%second_row:
    cmp r11d, 1                   ; r11d == 1 ?
    jne .error                    ; если нет — ошибка
    cmp r12, r13                  ; y-чисел не больше, чем x?
    jae .error                    ; если r12 >= r13 — ошибка
    mov rax, [x_values + r12*8]   ; rax = x[r12]
    sub rax, r8                   ; rax -= y
    add r14, rax                  ; sum += rax
    inc r12
```

**Сброс:**

```asm
%%reset:
    xor r8, r8
    xor r9d, r9d
    xor r10d, r10d
    jmp %%no_number
%%no_number:
```

## 3.9. Секция `.bss`

```asm
section .bss
    buffer      resb 1024         ; 1024 байта под входные данные
    bytes_read  resq 1            ; 8 байт под число «сколько прочитано»
    ARRAY x_values, 128           ; 1024 байта под 128 x-чисел
    outbuf      resb 64           ; 64 байта под строку результата
```

`.bss` — сегмент с нулями, не занимает места в ELF-файле.

## 3.10. Секция `.data`

```asm
section .data
    prefix      db "filename: "
    prefix_len  equ $ - prefix
```

`db` пишет 10 байт: `f`, `i`, `l`, `e`, `n`, `a`, `m`, `e`, `:`, пробел.  
`$` в момент после `db` указывает на текущий адрес, `prefix` — на начало строки. `$ - prefix = 10`.

```asm
    wrong       db "filename: wrong data", 10
    wrong_len   equ $ - wrong
```

`10` в конце — символ `\n`. Длина строки — 23 байта.

## 3.11. Секция `.text`

```asm
section .text
global _start
```

`_start` — точка входа, которую линкер указывает в ELF-заголовке.

### Проверка аргументов

```asm
_start:
    cmp qword [rsp], 2            ; argc == 2 ?
    jne .error
```

`qword` — квалификатор размера: сравниваем 8 байт по адресу `[rsp]`. На входе в `_start`:

```text
[rsp]      = argc
[rsp + 8]  = argv[0] (адрес строки с именем программы)
[rsp + 16] = argv[1] (адрес строки с именем файла)
[rsp + 24] = NULL
```

### Открытие файла

```asm
    OPEN [rsp + 16]               ; открыть argv[1]
    test rax, rax
    js .error                     ; если rax < 0 — ошибка
```

`js` переходит, если `SF = 1`, то есть `rax < 0` (знаковое).

### Чтение

```asm
    READ rax, buffer, 1024        ; читаем до 1024 байт
    test rax, rax
    js .error
    cmp rax, 1024
    jae .error                    ; прочитано ≥ 1024 — считаем ошибкой
```

Идея: если файл ровно 1024 байта или больше, мы могли не дочитать. Значит, не поддерживаем такие файлы.

### Сохранение состояния

```asm
    mov [bytes_read], rax         ; сохранить количество
    lea rsi, [rel buffer]         ; rsi = адрес buffer
    mov rcx, [bytes_read]         ; rcx = длина
```

`[bytes_read]` — косвенная адресация: берём значение из памяти по адресу `bytes_read`. `lea` же берёт сам адрес.

### Инициализация регистров

```asm
    xor r8, r8                    ; текущее число
    xor r9d, r9d                  ; флаг «были цифры»
    xor r10d, r10d                ; флаг «был минус»
    xor r11d, r11d                ; номер строки
    xor r12, r12                  ; счётчик y
    xor r13, r13                  ; счётчик x
    xor r14, r14                  ; сумма разностей
```

### Главный цикл — начало

```asm
.next_byte:
    test rcx, rcx                 ; байты кончились?
    jz .end_of_file
    mov al, [rsi]                 ; читаем байт
    inc rsi                       ; указатель вперёд
    dec rcx                       ; счётчик вниз
    cmp r11d, 2                   ; после второй строки?
    je .trailing_data
```

### Классификация символа

```asm
    cmp al, '0'
    jb .not_digit                 ; если меньше '0' — не цифра
    cmp al, '9'
    ja .not_digit                 ; если больше '9' — не цифра
    ADD_DIGIT
    jmp .next_byte
```

Сравнение беззнаковое (символы — байты 0..255), поэтому `jb` / `ja` подходят.

### Не цифра

```asm
.not_digit:
    cmp al, '-'
    je .minus
    cmp al, 10                    ; LF (\n)
    je .newline
    cmp al, ','
    je .separator
    cmp al, ' '
    je .separator
    cmp al, 9                     ; TAB
    je .separator
    cmp al, 13                    ; CR
    je .separator
    jmp .error
```

### Минус

```asm
.minus:
    test r9d, r9d                 ; цифры уже были?
    jnz .error                    ; да — минус не в начале
    test r10d, r10d               ; минус уже был?
    jnz .error
    mov r10d, 1
    jmp .next_byte
```

### Разделитель

```asm
.separator:
    ADD_NUMBER
    jmp .next_byte
```

### Перевод строки

```asm
.newline:
    ADD_NUMBER
    cmp r11d, 0                   ; первая строка?
    je .start_second_row
    cmp r11d, 1                   ; вторая?
    jne .error
    cmp r12, r13                  ; количества совпали?
    jne .error
    test r12, r12                 ; ноль чисел?
    jz .error
    mov r11d, 2
    jmp .next_byte

.start_second_row:
    test r13, r13
    jz .error
    mov r11d, 1
    jmp .next_byte
```

### Данные после второй строки

```asm
.trailing_data:
    cmp al, ' '
    je .next_byte
    cmp al, 9
    je .next_byte
    cmp al, 10
    je .next_byte
    cmp al, 13
    je .next_byte
    jmp .error
```

### Конец файла

```asm
.end_of_file:
    ADD_NUMBER
    cmp r11d, 0
    je .error
    cmp r12, r13
    jne .error
    test r13, r13
    jz .error
```

### Вычисление среднего

```asm
    mov rax, r14                  ; rax = сумма разностей
    cqo                           ; знаковое расширение в rdx:rax
    mov rcx, r13                  ; rcx = количество
    idiv rcx                      ; rax = среднее, rdx = остаток
```

### Форматирование результата

```asm
    xor r15d, r15d                ; флаг отрицательного = 0
    test rax, rax
    jns .format_number            ; если rax >= 0
    mov r15d, 1                   ; запомнили минус
    neg rax                       ; сделали положительным
```

```asm
.format_number:
    lea rdi, [rel outbuf + 63]    ; пишем справа налево
    mov byte [rdi], 10            ; '\n'
    mov rbx, 10                   ; делитель

.convert_loop:
    xor edx, edx                  ; обнулить старшую часть
    div rbx                       ; rdx:rax / 10
    add dl, '0'                   ; цифра в ASCII
    dec rdi
    mov [rdi], dl
    test rax, rax
    jnz .convert_loop
```

Почему `xor edx, edx` перед `div`? Потому что `div rbx` делит `rdx:rax` на `rbx`. Если `rdx` содержит мусор, результат будет неправильным. Обнуляем `rdx` — теперь деление фактически 64-битное.

```asm
    test r15d, r15d
    jz .write_result
    dec rdi
    mov byte [rdi], '-'
```

### Вывод

```asm
.write_result:
    mov r12, rdi                  ; начало строки с числом
    WRITE prefix, prefix_len      ; печатаем "filename: "

    mov eax, 1                    ; sys_write
    mov edi, 1                    ; stdout
    mov rsi, r12                  ; начало строки числа
    lea rdx, [rel outbuf + 64]    ; конец буфера
    sub rdx, r12                  ; длина = конец - начало
    syscall

    EXIT 0
```

### Обработка ошибки

```asm
.error:
    WRITE wrong, wrong_len
    EXIT 1
```

---

# Часть 4. Карта регистров и их роли

| Регистр | Роль | Где меняется |
|---|---|---|
| `rax` | syscall number / временное / делимое | везде |
| `rbx` | делитель 10 в `.convert_loop` | `.format_number` |
| `rcx` | счётчик байт / делитель при `idiv` | главный цикл, деление |
| `rdx` | старшая часть делимого / temp | `ADD_DIGIT`, `div`, `idiv` |
| `rdi` | буфер/указатель для syscall / позиция записи | `WRITE`, `EXIT`, `OPEN`, `READ`, `.convert_loop` |
| `rsi` | адрес текущего байта / аргумент syscall | `READ`, `WRITE`, главный цикл |
| `r8` | текущее собираемое число | `ADD_DIGIT`, `ADD_NUMBER` |
| `r9d` | флаг «были цифры» | `ADD_DIGIT`, `ADD_NUMBER` |
| `r10d` | флаг «был минус» | `.minus`, `ADD_NUMBER` |
| `r11d` | номер строки (0/1/2) | `.newline` |
| `r12` | счётчик y / начало строки результата | главный цикл, `.write_result` |
| `r13` | счётчик x / делитель | `ADD_NUMBER` |
| `r14` | сумма разностей | `ADD_NUMBER` |
| `r15d` | флаг «отрицательный результат» | `.format_number` |
| `al` | текущий байт | `.next_byte` |
| `dl` | цифра при выводе | `.convert_loop` |

---

# Часть 5. Что делает программа в целом — сценарий

Файл `data.txt`:

```text
10 20 30
1 2 3
```

1. Проверка `argc == 2`.
2. `open("data.txt", O_RDONLY)`.
3. `read(fd, buffer, 1024)`.
4. Разбор:
   - `'1'` → `ADD_DIGIT`, `r8 = 1`;
   - `'0'` → `ADD_DIGIT`, `r8 = 10`;
   - `' '` → `ADD_NUMBER`: `x_values[0] = 10`, `r13 = 1`;
   - `'2'`, `'0'` → `r8 = 20`;
   - `' '` → `x_values[1] = 20`, `r13 = 2`;
   - `'3'`, `'0'` → `r8 = 30`;
   - `'\n'` → `ADD_NUMBER`: `x_values[2] = 30`, `r13 = 3`; `r11d = 1`;
   - `'1'` → `r8 = 1`;
   - `' '` → `ADD_NUMBER` второй строки: `r14 += 10 - 1 = 9`, `r12 = 1`;
   - `'2'` → `r8 = 2`;
   - `' '` → `r14 += 20 - 2 = 18`, `r14 = 27`, `r12 = 2`;
   - `'3'` → `r8 = 3`;
   - `'\n'` → `r14 += 30 - 3 = 27`, `r14 = 54`, `r12 = 3`; `r11d = 2`.
5. Конец файла: `r12 == r13 == 3`.
6. `54 / 3 = 18`.
7. Печать `"filename: 18\n"`.

---

# Часть 6. Ограничения и возможные проблемы

1. **Размер файла ≤ 1023 байта.** Если файл длиннее, программа считает это ошибкой.
2. **Не более 128 чисел в первой строке.** Массив `x_values` фиксированного размера.
3. **Нет дозаписи.** Файл читается одним `read`.
4. **Нет проверки ошибок записи.** `WRITE` не проверяет результат.
5. **Не поддерживается пустой файл.** Требуются две непустые строки.
6. **Нет `O_CLOEXEC`** и других флагов.
7. **Только Linux x86-64.** На других архитектурах или ОС не соберётся/не запустится.
