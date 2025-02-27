section .data
    GRID_SIZE equ 4                  ; Size of the 4x4 grid
    grid dd 16 dup(0)                ; 4x4 game board initialized with zeros (16 integers)
    new_tile_values dd 2, 4          ; Possible values for a new tile (2 or 4)
    game_over_msg db "Game Over!", 10, 0  ; Game over message with a newline
    prompt_msg db "Use w/a/s/d to move: ", 0  ; Prompt for user input
    error_msg db "Invalid input.", 10, 0      ; Error message for invalid input
    newline db 10                    ; Newline character

section .bss
    key_input resb 1                 ; Reserve 1 byte for user input

section .text
global _start

; Program entry point
_start:
    call initialize_game             ; Initialize the game with 2 tiles
    jmp main_loop                    ; Jump to the main loop

; Main game loop
main_loop:
    call display_grid                ; Display the grid
    call print_prompt                ; Display the prompt
    call get_user_input              ; Get user input
    call handle_input                ; Handle the input
    call generate_tile               ; Generate a new tile
    call check_game_over             ; Check if the game is over
    jmp main_loop                    ; Infinite loop until the game ends

; Exit the program
exit_game:
    mov eax, 1                       ; System call number for exit
    xor ebx, ebx                     ; Return code 0
    int 0x80                         ; System interrupt

; Initialize the game with two random tiles
initialize_game:
    call generate_tile               ; Generate the first tile
    call generate_tile               ; Generate the second tile
    ret

; Display the game grid
display_grid:
    push ebx                         ; Save registers
    push ecx
    mov ecx, 0                       ; Counter to iterate through the grid
.print_loop:
    cmp ecx, 16                      ; Check if all cells have been iterated
    jge .done
    ; Display a horizontal line every 4 elements or at the start
    mov eax, ecx
    and eax, 3                       ; Check if it’s a multiple of 4
    cmp eax, 0
    jne .no_line
    push ecx
    call print_horizontal_line       ; Display a separator line
    pop ecx
.no_line:
    mov eax, [grid + ecx * 4]        ; Load the cell value
    test eax, eax                    ; Check if the cell is empty
    jz .empty
    push ecx
    call print_padded_number         ; Display the number with padding
    pop ecx
    jmp .next
.empty:
    push ecx
    mov eax, ' '
    call print_character             ; Display 4 spaces for an empty cell
    call print_character
    call print_character
    call print_character
    pop ecx
.next:
    push ecx
    mov eax, '|'                     ; Vertical separator between cells
    call print_character
    pop ecx
    inc ecx                          ; Move to the next cell
    mov eax, ecx
    and eax, 3                       ; Newline every 4 elements
    cmp eax, 0
    jne .print_loop
    push ecx
    call print_newline               ; Add a newline
    pop ecx
    jmp .print_loop
.done:
    push ecx
    call print_horizontal_line       ; Final line
    pop ecx
    pop ecx
    pop ebx
    ret

; Display a number with padding for alignment
print_padded_number:
    push ebx
    push ecx
    push edx
    mov ebx, 10                      ; Base 10 for conversion
    xor ecx, ecx                     ; Digit counter
    test eax, eax                    ; Check if the number is 0
    jz .zero_case
.convert:
    test eax, eax                    ; Convert to digits
    jz .padding
    xor edx, edx
    div ebx                          ; Divide by 10
    add dl, '0'                      ; Convert remainder to character
    push edx                         ; Push the character
    inc ecx                          ; Increment digit counter
    jmp .convert
.zero_case:
    mov eax, ' '
    call print_character             ; Display "  0 "
    call print_character
    mov eax, '0'
    call print_character
    mov eax, ' '
    call print_character
    jmp .done
.padding:
    cmp ecx, 1                       ; Add padding based on digit count
    jne .two_digits
    mov eax, ' '
    call print_character             ; 2 spaces before a single digit
    call print_character
    jmp .print
.two_digits:
    mov eax, ' '                     ; 1 space before two digits
    call print_character
.print:
    test ecx, ecx                    ; Display stacked digits
    jz .add_space
    pop eax
    call print_character
    dec ecx
    jmp .print
.add_space:
    mov eax, ' '                     ; Space after the number
    call print_character
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; Display a horizontal line
print_horizontal_line:
    push ecx
    mov ecx, 0
.line_loop:
    mov eax, '-'                     ; Line character
    call print_character
    inc ecx
    cmp ecx, 21                      ; Total length (4 cells * 5 + 1)
    jl .line_loop
    call print_newline               ; End of line
    pop ecx
    ret

; Display the prompt for user input
print_prompt:
    mov edx, prompt_msg
    call print_string
    ret

; Get user input
get_user_input:
    mov eax, 3                       ; System call for read
    xor ebx, ebx                     ; File descriptor 0 (stdin)
    lea ecx, [key_input]             ; Address to store input
    mov edx, 1                       ; Read 1 byte
    int 0x80
    cmp byte [key_input], 0x0A       ; Ignore newlines
    je get_user_input
    ret

; Handle user input
handle_input:
    movzx eax, byte [key_input]      ; Load input as a byte
    cmp eax, 'w'
    je move_up                       ; Move up
    cmp eax, 'a'
    je move_left                     ; Move left
    cmp eax, 's'
    je move_down                     ; Move down
    cmp eax, 'd'
    je move_right                    ; Move right
    mov edx, error_msg               ; Message for invalid input
    call print_string
    ret

; Move left
move_left:
    mov ecx, 0                       ; Row counter
.move_left_loop:
    call shift_left                  ; Shift tiles left
    call merge_left                  ; Merge identical tiles
    call shift_left                  ; Shift again after merging
    inc ecx
    cmp ecx, GRID_SIZE               ; Check all rows
    jl .move_left_loop
    ret

; Shift tiles left in a row
shift_left:
    mov esi, ecx
    imul esi, GRID_SIZE              ; Starting index of the row
    mov edi, esi                     ; Destination index
.shift_loop:
    cmp esi, 16                      ; Grid limit
    jge .done
    mov eax, [grid + esi * 4]        ; Load value
    test eax, eax                    ; Check if empty
    jz .next
    mov [grid + edi * 4], eax        ; Place value at target position
    cmp esi, edi
    je .no_clear
    mov dword [grid + esi * 4], 0    ; Clear source position if different
.no_clear:
    inc edi                          ; Advance target position
.next:
    inc esi                          ; Move to next cell
    mov eax, ecx
    imul eax, GRID_SIZE
    add eax, GRID_SIZE               ; Row limit
    cmp esi, eax
    jl .shift_loop
.done:
    ret

; Merge tiles left
merge_left:
    mov esi, ecx
    imul esi, GRID_SIZE              ; Start of the row
    mov eax, esi
    add eax, GRID_SIZE - 1           ; End of the row
.merge_loop:
    cmp esi, eax
    jge .done
    mov ebx, [grid + esi * 4]        ; Load current tile
    test ebx, ebx                    ; Check if empty
    jz .next_merge
    cmp esi, 15                      ; Avoid overflow
    jge .next_merge
    mov edx, [grid + (esi + 1) * 4]  ; Load next tile
    cmp ebx, edx
    jne .next_merge
    add ebx, ebx                     ; Double the value
    mov [grid + esi * 4], ebx        ; Update the tile
    mov dword [grid + (esi + 1) * 4], 0  ; Clear merged tile
.next_merge:
    inc esi
    jmp .merge_loop
.done:
    ret

; Move right
move_right:
    mov ecx, 0                       ; Row counter
.move_right_loop:
    call shift_right                 ; Shift tiles right
    call merge_right                 ; Merge identical tiles
    call shift_right                 ; Shift again after merging
    inc ecx
    cmp ecx, GRID_SIZE               ; Check all rows
    jl .move_right_loop
    ret

; Shift tiles right in a row
shift_right:
    mov esi, ecx
    imul esi, GRID_SIZE
    add esi, GRID_SIZE - 1           ; Starting index (end of the row)
    mov edi, esi                     ; Destination index
.shift_loop:
    cmp esi, 0                       ; Grid limit
    jl .done
    mov eax, [grid + esi * 4]        ; Load value
    test eax, eax                    ; Check if empty
    jz .next
    mov [grid + edi * 4], eax        ; Place value at target position
    cmp esi, edi
    je .no_clear
    mov dword [grid + esi * 4], 0    ; Clear source position if different
.no_clear:
    dec edi                          ; Move target position back
.next:
    dec esi                          ; Move to previous cell
    mov eax, ecx
    imul eax, GRID_SIZE              ; Start of the row
    cmp esi, eax
    jge .shift_loop
.done:
    ret

; Merge tiles right
merge_right:
    mov esi, ecx
    imul esi, GRID_SIZE
    add esi, GRID_SIZE - 1           ; Start at the end of the row
    mov eax, ecx
    imul eax, GRID_SIZE              ; Start of the row
.merge_loop:
    cmp esi, eax
    jle .done
    mov ebx, [grid + esi * 4]        ; Load current tile
    test ebx, ebx                    ; Check if empty
    jz .next_merge
    cmp esi, 0                       ; Avoid overflow
    jle .next_merge
    mov edx, [grid + (esi - 1) * 4]  ; Load previous tile
    cmp ebx, edx
    jne .next_merge
    add ebx, ebx                     ; Double the value
    mov [grid + esi * 4], ebx        ; Update the tile
    mov dword [grid + (esi - 1) * 4], 0  ; Clear merged tile
.next_merge:
    dec esi
    jmp .merge_loop
.done:
    ret

; Move up
move_up:
    mov ecx, 0                       ; Column counter
.move_up_loop:
    call shift_up                    ; Shift tiles up
    call merge_up                    ; Merge identical tiles
    call shift_up                    ; Shift again after merging
    inc ecx
    cmp ecx, GRID_SIZE               ; Check all columns
    jl .move_up_loop
    ret

; Shift tiles up in a column
shift_up:
    mov esi, ecx                     ; Starting index (top of the column)
    mov edi, esi                     ; Destination index
.shift_loop:
    cmp esi, GRID_SIZE * GRID_SIZE   ; Grid limit
    jge .done
    mov eax, [grid + esi * 4]        ; Load value
    test eax, eax                    ; Check if empty
    jz .next
    mov [grid + edi * 4], eax        ; Place value at target position
    cmp esi, edi
    je .no_clear
    mov dword [grid + esi * 4], 0    ; Clear source position if different
.no_clear:
    add edi, GRID_SIZE               ; Advance target position (downward)
.next:
    add esi, GRID_SIZE               ; Move to next cell (downward)
    jmp .shift_loop
.done:
    ret

; Merge tiles up
merge_up:
    mov esi, ecx                     ; Start of the column
    mov eax, ecx
    add eax, (GRID_SIZE - 1) * GRID_SIZE  ; End of the column
.merge_loop:
    cmp esi, eax
    jge .done
    mov ebx, [grid + esi * 4]        ; Load current tile
    test ebx, ebx                    ; Check if empty
    jz .next_merge
    mov edx, [grid + (esi + GRID_SIZE) * 4]  ; Load next tile
    cmp ebx, edx
    jne .next_merge
    add ebx, ebx                     ; Double the value
    mov [grid + esi * 4], ebx        ; Update the tile
    mov dword [grid + (esi + GRID_SIZE) * 4], 0  ; Clear merged tile
.next_merge:
    add esi, GRID_SIZE               ; Move to next cell
    jmp .merge_loop
.done:
    ret

; Move down
move_down:
    mov ecx, 0                       ; Column counter
.move_down_loop:
    call shift_down                  ; Shift tiles down
    call merge_down                  ; Merge identical tiles
    call shift_down                  ; Shift again after merging
    inc ecx
    cmp ecx, GRID_SIZE               ; Check all columns
    jl .move_down_loop
    ret

; Shift tiles down in a column
shift_down:
    mov esi, ecx
    add esi, (GRID_SIZE - 1) * GRID_SIZE  ; Starting index (bottom of the column)
    mov edi, esi                     ; Destination index
.shift_loop:
    cmp esi, 0                       ; Grid limit
    jl .done
    mov eax, [grid + esi * 4]        ; Load value
    test eax, eax                    ; Check if empty
    jz .next
    mov [grid + edi * 4], eax        ; Place value at target position
    cmp esi, edi
    je .no_clear
    mov dword [grid + esi * 4], 0    ; Clear source position if different
.no_clear:
    sub edi, GRID_SIZE               ; Move target position up
.next:
    sub esi, GRID_SIZE               ; Move to previous cell (upward)
    jmp .shift_loop
.done:
    ret

; Merge tiles down
merge_down:
    mov esi, ecx
    add esi, (GRID_SIZE - 1) * GRID_SIZE  ; Start at the bottom of the column
    mov eax, ecx                     ; Top of the column
.merge_loop:
    cmp esi, eax
    jle .done
    mov ebx, [grid + esi * 4]        ; Load current tile
    test ebx, ebx                    ; Check if empty
    jz .next_merge
    mov edx, [grid + (esi - GRID_SIZE) * 4]  ; Load previous tile
    cmp ebx, edx
    jne .next_merge
    add ebx, ebx                     ; Double the value
    mov [grid + esi * 4], ebx        ; Update the tile
    mov dword [grid + (esi - GRID_SIZE) * 4], 0  ; Clear merged tile
.next_merge:
    sub esi, GRID_SIZE               ; Move to previous cell
    jmp .merge_loop
.done:
    ret

; Generate a new random tile
generate_tile:
    push ebx
    push ecx
    push edx
    xor ebx, ebx                     ; Counter for empty cells
    mov ecx, 0
.count_empty:
    cmp ecx, 16
    jge .check_empty
    mov eax, [grid + ecx * 4]
    test eax, eax
    jnz .next_empty
    inc ebx                          ; Increment if empty
.next_empty:
    inc ecx
    jmp .count_empty
.check_empty:
    test ebx, ebx                    ; Check if there are empty cells
    jz .done
    call simple_random               ; Generate a random number
    xor edx, edx
    div ebx                          ; Calculate a random index
    mov eax, edx                     ; Random index among empty cells
    mov ecx, 0
    xor ebx, ebx                     ; Counter for found empty cells
.find_nth_empty:
    cmp ecx, 16
    jge .done
    mov edx, [grid + ecx * 4]
    test edx, edx
    jnz .skip
    cmp ebx, eax                     ; Find the nth empty cell
    je .place_tile
    inc ebx                          ; Increment counter
.skip:
    inc ecx
    jmp .find_nth_empty
.place_tile:
    mov edx, 2                       ; Place a tile with value 2
    mov [grid + ecx * 4], edx
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; Simple random number generator based on rdtsc
simple_random:
    push ebx
    rdtsc                            ; Get timestamp counter into eax
    mov ebx, 1664525
    mul ebx                          ; Multiply for pseudo-randomness
    add eax, 1013904223              ; Add a constant (simplified LCG)
    pop ebx
    ret

; Check if the game is over
check_game_over:
    mov ecx, 0
.check_empty:
    cmp ecx, 16
    jge .check_moves
    mov eax, [grid + ecx * 4]
    test eax, eax                    ; Check if there are empty cells
    jz .not_over
    inc ecx
    jmp .check_empty
.check_moves:
    mov ecx, 0
.check_row_loop:
    cmp ecx, GRID_SIZE
    jge .check_col_loop
    mov esi, ecx
    imul esi, GRID_SIZE
    mov eax, esi
    add eax, GRID_SIZE - 1
.check_row:
    cmp esi, eax
    jge .next_row
    mov ebx, [grid + esi * 4]
    mov edx, [grid + (esi + 1) * 4]
    cmp ebx, edx                     ; Check for possible horizontal merges
    je .not_over
    inc esi
    jmp .check_row
.next_row:
    inc ecx
    jmp .check_row_loop
.check_col_loop:
    mov ecx, 0
.check_col:
    cmp ecx, GRID_SIZE
    jge .game_over
    mov esi, ecx
    mov eax, ecx
    add eax, (GRID_SIZE - 1) * GRID_SIZE
.check_col_inner:
    cmp esi, eax
    jge .next_col
    mov ebx, [grid + esi * 4]
    mov edx, [grid + (esi + GRID_SIZE) * 4]
    cmp ebx, edx                     ; Check for possible vertical merges
    je .not_over
    add esi, GRID_SIZE
    jmp .check_col_inner
.next_col:
    inc ecx
    jmp .check_col
.game_over:
    mov edx, game_over_msg
    call print_string                ; Display game over message
    jmp exit_game
.not_over:
    ret

; Display a string
print_string:
    push ecx
    mov ecx, edx                     ; Pointer to the string
    call string_length               ; Calculate length
    mov eax, 4                       ; System call for write
    mov ebx, 1                       ; stdout
    int 0x80
    pop ecx
    ret

; Display a number
print_number:
    push ebx
    push ecx
    push edx
    test eax, eax                    ; Check if the number is 0
    jnz .convert
    mov eax, '0'                     ; Display 0 if value is zero
    call print_character
    jmp .done
.convert:
    mov ebx, 10                      ; Base 10
    xor ecx, ecx                     ; Digit counter
.convert_loop:
    test eax, eax
    jz .print
    xor edx, edx
    div ebx                          ; Divide by 10
    add dl, '0'                      ; Convert remainder to character
    push edx                         ; Push the character
    inc ecx
    jmp .convert_loop
.print:
    test ecx, ecx                    ; Display stacked digits
    jz .done
    pop eax
    call print_character
    dec ecx
    jmp .print
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; Display a character
print_character:
    push ebx                         ; Save registers
    push ecx
    push edx
    push eax                         ; Push the character
    mov ecx, esp                     ; Point to the character
    mov eax, 4                       ; System call for write
    mov ebx, 1                       ; stdout
    mov edx, 1                       ; 1 byte
    int 0x80
    pop eax                          ; Restore stack
    pop edx
    pop ecx
    pop ebx
    ret

; Display a newline
print_newline:
    mov eax, 4                       ; System call for write
    mov ebx, 1                       ; stdout
    lea ecx, [newline]               ; Pointer to newline character
    mov edx, 1                       ; 1 byte
    int 0x80
    ret

; Calculate string length
string_length:
    xor edx, edx                     ; Counter
.loop:
    cmp byte [ecx + edx], 0          ; Check for null terminator
    je .done
    inc edx
    jmp .loop
.done:
    ret
