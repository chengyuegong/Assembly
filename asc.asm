; ASCII Table
code segment
assume cs:code
main:
	mov ax, 0B800h
	mov es, ax
	xor di, di; di = 0
; 清屏
	mov cx, 25*80
black:
	mov es:[di], 0000h
	add di, 2
	sub cx, 1
	jnz black

	xor di, di; di = 0
	mov cl, 25; 每列循环25次
	mov ch, 255; 共循环256次
	mov al, 0; al = 0
	mov ah, 04h; 黑底红字输出ASCII码

again:
	mov es:[di], ax;第一位赋值
;第二位赋值
	add di, 2; 换到下一个位置输出16进制
	mov dx, ax; dx = ax
	push cx
	mov cl, 12
	rol dx,	cl; 循环左移12位得到第一位16进制
	pop cx
	push dx; 保存dx
	call hex
;第三位赋值
	add di, 2; 换到下一个位置输出16进制
	pop dx; 恢复dx
	push cx
	mov cl, 4
	rol dx, cl; 循环左移4位得到第二位16进制
	pop cx
	call hex

	sub di, 4
	add di, 160; 换到下一行
	add al, 1; 输出字符值+1
	sub ch, 1
	jb finish; 检查总循环是否结束
	sub cl, 1
	jnz again; 检查每列循环是否结束

	mov cl, 25; 重置下一次循环次数
	sub di, 160*25; 返回第一行
	add di, 14; 前进7格（空4格）
	jmp again

finish:
	mov ah, 0
	int 16h; stop to press a key
	mov ah, 4Ch
	int 21h

;16进制转换
hex:
	and dx, 000Fh
	cmp dx, 10
	jb is_digit
is_alpha:
   	sub dl, 10
   	add dl, 'A'
   	jmp in_finish
is_digit:
   	add dl, '0'
in_finish:
	mov dh, 02h; 黑底绿字输出16进制
	mov es:[di], dx
	ret

code ends
end main