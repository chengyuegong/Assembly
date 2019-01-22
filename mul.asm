; Multiplication
.386
data segment use16
	num1 db 6; 最大字符数
		 db ?; 实际输入字符数
		 db 6 dup(?); 0 <= num1 <= 65535(16位非符号数)
	num2 db 6; 最大字符数
		 db ?; 实际输入字符数
		 db 6 dup(?); 0 <= num2 <= 65535(16位非符号数)
	s1 db 10 dup(0), 0Dh, 0Ah, '$'; 保存十进制输出字符串
	s2 db 8 dup(0), 'h', 0Dh, 0Ah, '$'; 保存十六进制输出字符串
	s3 db 32 dup(0), 'B', 0Dh, 0Ah, '$'; 保存二进制输出字符串
data ends

code segment use16
assume cs:code, ds:data
main:
	mov ax, data
	mov ds, ax
; 输入第一个字符串（存入num1）
	mov dx, offset num1
	mov ah, 0Ah
	int 21h
	call printr
; 输入第二个字符串（存入num2）
	mov dx, offset num2
	mov ah, 0Ah
	int 21h
	call printr

	mov cx, 0
; 输出被乘数
	mov cl, num1[1]; cl=num1字符串长度=循环次数
	mov bx, offset num1+2; bx=num1字符串起始地址
again1:
	call printbx
	inc bx; bx++
	loop again1
; 输出乘号
	mov dl, '*'
	mov ah, 2
	int 21h
; 输出乘数
	mov cl, num2[1]; cl=num2字符串长度=循环次数
	mov bx, offset num2+2; bx=num2字符串起始地址
again2:
	call printbx
	inc bx; bx++
	loop again2
; 输出等号
	mov dl, '='
	mov ah, 2
	int 21h
; 回车换行
	call printr

	mov edx, 0
; 将num2转换为数(65535)并push
	mov cl, num2[1]; cl=num2字符串长度=循环次数
	mov bx, offset num2+2; bx=num2字符串起始地址
	mov eax, 0
again3:
	imul ax, 10; ax=ax*10; ax=0*10=0 -- ax=6*10=60 -- ... -- ax=65530
	mov dl, [bx]
	sub dl, '0'
	add ax, dx; ax=ax+dx; ax=0+6=6 -- ax=60+5=65 -- ... -- ax=65535
	inc bx; bx++
	loop again3

	push ax; 保存乘数

; 将num1转换为数(12345)存入EAX
	mov cl, num1[1]; cl=num1字符串长度=循环次数
	mov bx, offset num1+2; bx=num2字符串起始地址
	mov ax, 0	
again4:
	imul ax, 10; ax=ax*10; ax=0*10=0 -- ax=1*10=10 -- ... -- ax=12340
	mov dl, [bx]
	sub dl, '0'
	add ax, dx; ax=0+1=1 -- ax=10+2=12 -- ... -- ax=12345
	inc bx; bx++
	loop again4

	pop dx; dx=乘数
	mul edx; EDX:EAX = EAX*EDX; EAX=12345*65535=3038CFC7h, EDX=0
	push eax; 保存EAX

;转换为十进制
	mov di, 0
	mov cx, 0; 统计push的次数
push_again:
 	mov edx, 0; 被除数为EDX:EAX
 	mov ebx, 10
 	div ebx; EAX=商, EDX=余数
  	add dl, '0'
	push dx
  	inc cx
  	cmp eax, 0
  	jne push_again
pop_again:
  	pop dx
  	mov s1[di], dl
  	inc di; di++
  	loop pop_again
;输出十进制字符串
  	mov ah, 9
  	mov dx, offset s1
  	int 21h

  	pop eax; 重新载入EAX
  	push eax; 再次保存EAX
;转换为十六进制
	mov di, 0
 	mov cl, 8; 循环左移8次	
again5:
	push cx
	mov cl, 4
	rol eax, cl; 循环左移4位
	push eax
	and eax, 0000000Fh
	cmp ax, 10
	jb is_digit
is_alpha:
	sub al, 10
	add al, 'A'
	jmp finish_4bits
is_digit:
	add al, '0'
finish_4bits:
	mov s2[di], al
	pop eax
	pop cx
	inc di; di++
	loop again5
;输出十六进制
	mov ah, 9
	mov dx, offset s2
	int 21h

	pop eax; 重新载入EAX
;转换为二进制
	mov di, 0
	mov cl, 32; 循环左移动32次
again6:
	rol eax, 1; 循环左移1位
	push eax
	and eax, 1
	add al, '0'
	mov s3[di], al
	pop eax
	inc di; di++
	loop again6
;输出二进制
	mov cl, 7; 先将前28位输出（带空格），循环7次
	mov bx, offset s3
again7:
	push cx
	mov cl, 4; 循环4次
	again8:
		call printbx
		inc bx; bx++
		loop again8
	pop cx
	mov dl, ' '; 输出空格
	mov ah, 2
	int 21h
	loop again7
	mov cx, 7; 再将最后4位和‘B'以及回车换行符输出
again9:
	call printbx
	inc bx; bx++
	loop again9

done:
	mov ah, 4Ch
	int 21h

; 输出回车和换行符
printr:
	mov dl, 0Dh
	mov ah, 2
	int 21h
	mov dl, 0Ah
	mov ah, 2
	int 21h
	ret

; 输出[bx]位置的字符
printbx:
	mov dl, [bx]
	mov ah, 2
	int 21h
	ret

code ends
end main