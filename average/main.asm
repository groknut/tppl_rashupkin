; Читает файл с двумя строками чисел, считает среднее от (x[i] - y[i]).

; ---------------------------------------------------------------------------
; Макросы системных вызовов
; ---------------------------------------------------------------------------

%macro WRITE 2                    ; макрос write(buf, len)
    mov eax, 1                    ; sys_write
    mov edi, 1                    ; fd = stdout
    mov rsi, %1                   ; адрес буфера
    mov edx, %2                   ; длина
    syscall                       ; вызов ядра
%endmacro

%macro EXIT 1                     ; макрос exit(code)
    mov eax, 60                   ; sys_exit
    mov edi, %1                   ; код возврата
    syscall                       ; вызов ядра
%endmacro

%macro OPEN 1                     ; макрос open(path)
    mov rdi, %1                   ; путь к файлу
    xor esi, esi                  ; flags = O_RDONLY флаг для чтения
    xor edx, edx                  ; mode = 0
    mov eax, 2                    ; sys_open
    syscall                       ; вызов ядра
%endmacro

%macro READ 3                     ; макрос read(fd, buf, size)
    mov rdi, %1                   ; файловый дескриптор
    mov rsi, %2                   ; буфер
    mov edx, %3                   ; размер
    xor eax, eax                  ; sys_read
    syscall                       ; вызов ядра
%endmacro

%macro ARRAY 2                    ; макрос объявления массива
    %1 resq %2                    ; резервируем %2 qword-ов под имя %1
%endmacro

; ---------------------------------------------------------------------------
; Разбор чисел
; ---------------------------------------------------------------------------

%macro ADD_DIGIT 0                ; добавить цифру из al к числу в r8
    sub al, '0'                   ; ASCII -> число
    imul r8, r8, 10               ; r8 *= 10
    movzx rdx, al                 ; расширяем цифру до 64 бит
    add r8, rdx                   ; r8 += цифра
    mov r9d, 1                    ; отметили: цифры были
%endmacro

%macro ADD_NUMBER 0               ; завершить текущее число
    test r9d, r9d                 ; были ли цифры?
    jz %%no_number                ; нет — выходим
    test r10d, r10d               ; был ли минус?
    jz %%positive                 ; нет — оставляем как есть
    neg r8                        ; да — меняем знак
%%positive:
    cmp r11d, 0                   ; первая строка?
    jne %%second_row              ; нет — идём во вторую
    cmp r13, 128                  ; не переполнен ли массив?
    jae .error                    ; да — ошибка
    mov [x_values + r13*8], r8    ; сохраняем x[i]
    inc r13                       ; счётчик x++
    jmp %%reset                   ; сброс состояния
%%second_row:
    cmp r11d, 1                   ; вторая строка?
    jne .error                    ; нет — ошибка
    cmp r12, r13                  ; y-чисел не больше, чем x?
    jae .error                    ; нет — ошибка
    mov rax, [x_values + r12*8]   ; берём x[i]
    sub rax, r8                   ; rax = x[i] - y[i]
    add r14, rax                  ; sum += разность
    inc r12                       ; счётчик y++
%%reset:
    xor r8, r8                    ; r8 = 0
    xor r9d, r9d                  ; флаг цифр = 0
    xor r10d, r10d                ; флаг минуса = 0
    jmp %%no_number               ; выходим
%%no_number:
%endmacro

; ---------------------------------------------------------------------------
; Данные
; ---------------------------------------------------------------------------

section .bss
    buffer      resb 1024         ; буфер ввода
    bytes_read  resq 1            ; сколько прочитано
    ARRAY x_values, 128           ; массив x (до 128 чисел)
    outbuf      resb 64           ; буфер вывода

section .data
    prefix      db "filename: "   ; префикс вывода
    prefix_len  equ $ - prefix    ; длина префикса

    wrong       db "filename: wrong data", 10  ; сообщение об ошибке
    wrong_len   equ $ - wrong                  ; его длина

; ---------------------------------------------------------------------------
; Код
; ---------------------------------------------------------------------------

section .text
global _start

_start:
    cmp qword [rsp], 2            ; argc == 2?
    jne .error                    ; нет — ошибка
    OPEN [rsp + 16]               ; open(argv[1])
    test rax, rax                 ; rax < 0?
    js .error                     ; да — ошибка
    READ rax, buffer, 1024        ; read(fd, buffer, 1024)
    test rax, rax                 ; rax < 0?
    js .error                     ; да — ошибка
    cmp rax, 1024                 ; прочитано ровно 1024?
    jae .error                    ; да — файл мог быть обрезан
    mov [bytes_read], rax         ; сохраняем количество
    lea rsi, [rel buffer]         ; rsi -> buffer
    mov rcx, [bytes_read]         ; rcx = счётчик байт

    xor r8, r8                    ; r8 = 0 (текущее число)
    xor r9d, r9d                  ; r9d = 0 (флаг цифр)
    xor r10d, r10d                ; r10d = 0 (флаг минуса)
    xor r11d, r11d                ; r11d = 0 (номер строки)
    xor r12, r12                  ; r12 = 0 (счётчик y)
    xor r13, r13                  ; r13 = 0 (счётчик x)
    xor r14, r14                  ; r14 = 0 (сумма разностей)

.next_byte:                       ; метка цикла
    test rcx, rcx                 ; байты закончились?
    jz .end_of_file               ; да — конец файла
    mov al, [rsi]                 ; читаем байт
    inc rsi                       ; указатель вперёд
    dec rcx                       ; счётчик вниз
    cmp r11d, 2                   ; уже после второй строки?
    je .trailing_data             ; да — только пробелы допустимы
    cmp al, '0'                   ; al < '0'?
    jb .not_digit                 ; да — не цифра
    cmp al, '9'                   ; al > '9'?
    ja .not_digit                 ; да — не цифра
    ADD_DIGIT                     ; добавляем цифру
    jmp .next_byte                ; следующий байт

.not_digit:
    cmp al, '-'                   ; это минус?
    je .minus                     ; да — обрабатываем
    cmp al, 10                    ; это LF?
    je .newline                   ; да — новая строка
    cmp al, ','                   ; это запятая?
    je .separator                 ; да — разделитель
    cmp al, ' '                   ; это пробел?
    je .separator                 ; да — разделитель
    cmp al, 9                     ; это таб?
    je .separator                 ; да — разделитель
    cmp al, 13                    ; это CR?
    je .separator                 ; да — разделитель
    jmp .error                    ; иначе — ошибка

.minus:
    test r9d, r9d                 ; уже были цифры?
    jnz .error                    ; да — минус не в начале числа
    test r10d, r10d               ; уже был минус?
    jnz .error                    ; да — два минуса подряд
    mov r10d, 1                   ; отмечаем минус
    jmp .next_byte                ; следующий байт

.separator:
    ADD_NUMBER                    ; завершаем число
    jmp .next_byte                ; следующий байт

.newline:
    ADD_NUMBER                    ; завершаем число
    cmp r11d, 0                   ; первая строка?
    je .start_second_row          ; да — переход ко второй
    cmp r11d, 1                   ; вторая строка?
    jne .error                    ; нет — ошибка
    cmp r12, r13                  ; количества совпали?
    jne .error                    ; нет — ошибка
    test r12, r12                 ; 0 чисел?
    jz .error                     ; да — ошибка
    mov r11d, 2                   ; переходим в состояние «после второй»
    jmp .next_byte                ; следующий байт

.start_second_row:
    test r13, r13                 ; первая строка пуста?
    jz .error                     ; да — ошибка
    mov r11d, 1                   ; переходим ко второй строке
    jmp .next_byte                ; следующий байт

.trailing_data:
    cmp al, ' '                   ; пробел?
    je .next_byte                 ; да — ок
    cmp al, 9                     ; таб?
    je .next_byte                 ; да — ок
    cmp al, 10                    ; LF?
    je .next_byte                 ; да — ок
    cmp al, 13                    ; CR?
    je .next_byte                 ; да — ок
    jmp .error                    ; иначе — ошибка

.end_of_file:
    ADD_NUMBER                    ; завершаем последнее число
    cmp r11d, 0                   ; первая строка так и не началась?
    je .error                     ; да — ошибка
    cmp r12, r13                  ; количества совпали?
    jne .error                    ; нет — ошибка
    test r13, r13                 ; 0 чисел?
    jz .error                     ; да — ошибка

    mov rax, r14                  ; rax = сумма разностей
    cqo                           ; расширяем знак в rdx:rax
    mov rcx, r13                  ; rcx = количество
    idiv rcx                      ; rax = среднее
    xor r15d, r15d                ; флаг отрицательного = 0
    test rax, rax                 ; rax < 0?
    jns .format_number            ; нет — на вывод
    mov r15d, 1                   ; да — запомнили знак
    neg rax                       ; делаем положительным

.format_number:
    lea rdi, [rel outbuf + 63]    ; rdi -> конец буфера
    mov byte [rdi], 10            ; пишем '\n'
    mov rbx, 10                   ; делитель
.convert_loop:
    xor edx, edx                  ; edx = 0 перед делением
    div rbx                       ; rax = rax/10, rdx = остаток
    add dl, '0'                   ; цифра -> ASCII
    dec rdi                       ; сдвигаем указатель
    mov [rdi], dl                 ; пишем цифру
    test rax, rax                 ; ещё есть цифры?
    jnz .convert_loop             ; да — продолжаем
    test r15d, r15d               ; результат был отрицательным?
    jz .write_result              ; нет — без минуса
    dec rdi                       ; сдвигаем указатель
    mov byte [rdi], '-'           ; пишем минус

.write_result:
    mov r12, rdi                  ; r12 = начало строки результата
    WRITE prefix, prefix_len      ; печатаем "filename: "
    mov eax, 1                    ; sys_write
    mov edi, 1                    ; stdout
    mov rsi, r12                  ; начало числа
    lea rdx, [rel outbuf + 64]    ; конец буфера
    sub rdx, r12                  ; длина = конец - начало
    syscall                       ; выводим
    EXIT 0                        ; выход с кодом 0

.error:
    WRITE wrong, wrong_len        ; печатаем сообщение об ошибке
    EXIT 1                        ; выход с кодом 1
