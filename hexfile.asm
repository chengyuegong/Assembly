; Hex File Reader
.386
data segment use16
	bytes_on_row db 0; 行字节数(8位_0-16)
	handle dw 0; 文件句柄(16位)
	bytes_in_buf dw 0; 需输出字符数(16位_0-256)
	bytes_temp dw 0; 已输入字符数(16位_0-256)
	file_size dd 0; 文件大小(32位)
	offs dd 0; 文件偏移量(32位)
	tip db "Please input filename:", 0Dh, 0Ah, '$'; 输入提示字符串
	err db "Cannot open file!", 0Dh, 0Ah, '$'; 打开文件失败提示字符串
	filename  	db 100; 文件名最大字节数
				db ?; 文件名实际输入字节数
				db 100 dup(0); 文件名字符串
	buf db 256 dup(0); 单页输出字符
	s db "00000000:            |           |           |                             "; 显示行
data ends

code segment use16
assume ds:data, cs:code
main:
; ----------------准备工作---------------- Start
; DS=DATA, ES=0B800h
	mov ax, data
	mov ds, ax; ds=data
 	mov ax, 0B800h
	mov es, ax; es=B800
; 调用中断21h(ah=09h)--输出提示语
	mov ah, 09h; DS:DX -> '$'-terminated string
	mov dx, offset tip; tip="Please input filename:"
	int 21h
; 调用中断21h(ah=0Ah)--输入文件名
	mov ah, 0Ah; DS:DX -> buffer
	mov dx, offset filename
	int 21h
; 调用中断21h(ah=02h)--输出回车符
	mov ah, 02h; DL = character to write
	mov dl, 0Dh
	int 21h
; 调用中断21h(ah=02h)--输出换行符
	mov ah, 02h; DL = character to write
	mov dl, 0Ah
	int 21h
; 将文件名最后的回车0Dh设为0
	mov bx, offset filename+2; ds:bx->filename
	mov al, filename[1]; al=filename[1]
	cbw; 扩展为ax
	mov si, ax; ds:[bx+si]=0Dh
	mov [bx+si], 0; ds:[bx+si]=0
; handle = _open(filename, 0);
; 调用中断21h(ah=3Dh)--打开文件，返回AX=file handle，成功CF=0，失败CF=1
	mov ah, 3Dh; AL = access and sharing modes
			   ; DS:DX -> ASCIZ filename
	mov al, 0; 对应_open()的第2个参数, 表示只读方式
	mov dx, offset filename+2; ds:dx -> filename
 	int 21h
 	mov handle, ax; handle = ax
 	jc err_finish; CF=1，结束程序
; file_size = lseek(handle, 0, 2);
; 调用中断21h(ah=42h)--将指针移到文件末尾，返回文件大小DX:AX = new file position in bytes from start of file
	mov ah, 42h; AL = origin of move(00h start of file, 01h current file position, 02h end of file)
			   ; BX = file handle
			   ; CX:DX = (signed) offset from origin of new file position
 	mov al, 2; 对应lseek()的第3个参数, 表示以EOF为参照点进行移动
 	mov bx, handle
   	mov cx, 0; \ cx:dx对应lseek()的第2个参数
   	mov dx, 0; /
   	int 21h
   	mov word ptr file_size[2], dx; \ file_size=DX:AX
   	mov word ptr file_size[0], ax; / 
; ----------------准备工作---------------- End

; ----------------循环---------------- Start
do_while:
; 计算bytes_in_buf
	mov eax, file_size
	sub eax, offs; eax = file_size - offset
	cmp eax, 256
	jae ae_to_256
	mov bytes_in_buf, ax; if(eax<256) bytes_in_buf=ax
	jmp cont
	ae_to_256:
	mov bytes_in_buf, 256; if(eax>=256) bytes_in_buf=256
cont:
; lseek(handle, offset, 0)
; 调用中断21h(ah=42h)--将指针移至文件指定的offset处
	mov ah, 42h; AL = origin of move(00h start of file, 01h current file position, 02h end of file)
			   ; BX = file handle
			   ; CX:DX = (signed) offset from origin of new file position
 	mov al, 0; 对应lseek()的第3个参数, 表示以起始0为参照点进行移动
 	mov bx, handle
   	mov cx, word ptr offs[2]; \ cx:dx=offs
   	mov dx, word ptr offs[0]; / 对应lseek()的第2个参数
   	int 21h
; _read(handle, buf, bytes_in_buf)
; 调用中断21h(ah=3Fh)--将显示内容读到数组buf中
	mov ah, 3Fh; BX = file handle
			   ; CX = number of bytes to read
			   ; DS:DX -> buffer for data
   	mov bx, handle
   	mov cx, bytes_in_buf
   	mov dx, offset buf
   	int 21h
; show_this_page(buf, offset, bytes_in_buf)
; 从B800:0000开始填入80*16个0020h
	mov ax, 0020h; 填入字符
	mov cx, 80*16; 循环次数
	mov di, 0; 起始地址ES:[0]
	cld; DF=0
	rep stosw; 把ax中的值保存到es:di所指向的内存单元中，循环cx次
; cx=(bytes_in_buf+15)/16 循环次数
	mov cx, bytes_in_buf; cx=bytes_in_buf
	add cx, 15; cx+=15
	shr cx, 4; cx/=16
; 初始化各寄存器及内存变量
	mov bytes_temp, 0; bytes_temp=0
	mov bytes_on_row, 16; bytes_on_row=16
	mov edx, offs; edx=offs
	mov si, 0; si=0
	mov di, 0; di=0
; 空文件测试
	test cl, cl
	jz presskey
; ----------------显示---------------- Start
show_this_page:
	push cx
	push di; push-di=用来存B800偏移地址的di
	cmp cl, 1
	jz bor_not_16; if(cl==1) bytes_on_row=bytes_in_buf - bytes_temp
back:
; 将32位offs转换为十六进制放入s数组前8个字节
	mov di, 0; di=0
	mov eax, edx; eax=edx=offs
 	mov cl, 8; 循环左移8次	
first_8:
	push cx
	mov cl, 4
	rol eax, cl; 循环左移4位
	push eax
	call transfer_16
	pop eax
	pop cx
	loop first_8
; 将每行16个字符转换成16进制放入10-56格
	mov di, 10
	mov cl, bytes_on_row
out_1056:
	push cx
	mov al, buf[si]; ax=buf[si]
	inc si
	mov cl, 2; 循环左移2次
in_1056:
	push cx
	mov cl, 4
	rol al, cl; 循环左移4位
	push ax
	call transfer_16
	pop ax
	pop cx
	loop in_1056
	inc di
	pop cx
	loop out_1056
; 将16个字符的ascii字符放入59-74格
	mov di, 59
	mov cl, bytes_on_row
	sub si, cx; si-=bytes_on_row
last_16:
	mov al, buf[si]
	mov s[di], al; s[di]=buf[si]
	inc si; si++
	inc di; di++
	loop last_16	
; 将s数组中的75个字符转入地址B800:xxxx中
	pop di; pop-di=用来存B800偏移地址的di
	mov cl, 75; 循环75次
	push si
	mov si, 0
	jmp stoB800
back2:
	pop si
	pop cx
	add edx, 10h; edx+=16
	add bytes_temp, 10h; bytes_temp+=16
	loop show_this_page
; ----------------显示---------------- End
; switch(key)
presskey:
; 调用中断16h(ah=00h)--读键盘输入
	mov ah, 0; 返回AH = BIOS scan code, AL = ASCII character
	int 16h
	cmp ax, 011Bh; key == Esc(011Bh)
	jz finish
	cmp ax, 4900h; key == PageUP(4900h)
	jz PageUP
	cmp ax, 5100h; key == PageDown(5100h)
	jz PageDown
	cmp ax, 4700h; key == Home(4700h)
	jz Home
	cmp ax, 4F00h; key == End(4F00h)
	jz Endd
	jmp presskey
PageUP:
	sub offs, 100h; offs-=256
	jb below_0
	jmp do_while; if(off>=0) 显示上一页
	below_0:
	mov offs, 0; if(offs<0) offs=0
	jmp presskey
PageDown:
	mov eax, file_size; eax=file_size
	add offs, 100h; offs+=256
	cmp offs, eax
	jb below_file_size; 
	sub offs, 100h; if(offs>=file_size) offs-=256 恢复
	jmp presskey
	below_file_size:
	jmp do_while; if(offs<file_size) 显示下一页
Home:
	mov offs, 0; offs=0
	jmp do_while; 显示第一页
Endd:
	mov edx, file_size
	mov eax, edx; eax=edx=file_size
	test eax, eax
	jz presskey; 空文件
	and edx, 0FFh; edx=edx%256
	jz file_size_256mul
	sub eax, edx
	mov offs, eax; if(file_size%256!=0) offs=file_size-file_size%256
	jmp do_while
	file_size_256mul:
	sub eax, 100h
	mov offs, eax; if(file_size%256==0) offs=file_size-256
	jmp do_while
; ----------------循环---------------- End

; ----------------函数---------------- Start
; bytes_on_row=bytes_in_buf-bytes_temp
bor_not_16:
	mov ax, bytes_in_buf
	sub ax, bytes_temp
	mov bytes_on_row, al
; 由于最后一行显示字符数可能低于16，需要事先清空数组s
	push es
; 在s[10]-s[74]填入65个空字符
	mov ax, data
	mov es, ax
	mov al, 0; 填入空字符
	mov di, offset s+10; 从s[10]开始
	mov cl, 65; 循环65次 10-74
	cld
	rep stosb; 把al中的值保存到es:di所指向的内存单元中，循环cx次
	mov s[21], '|'
	mov s[33], '|'
	mov s[45], '|'
	pop es
	jmp back
; 将数组s内容存入地址B800:di中
stoB800:
	mov al, s[si]
	mov ah, 07h
	stosw; ES:[DI]=AX
	inc si
	loop stoB800
	sub di, 150; 移回行开头
; 将‘|’前景色设置为高亮度白色
	mov byte ptr es:[di+43], 0Fh
	mov byte ptr es:[di+67], 0Fh
	mov byte ptr es:[di+91], 0Fh
	add di, 160; 移到下一行
	jmp back2
; 转16进制函数
transfer_16:
	and ax, 0Fh
	cmp al, 10
	jb is_digit
is_alpha:
	sub al, 10
	add al, 'A'
	jmp finish_4bits
is_digit:
	add al, '0'
finish_4bits:
	mov s[di], al
	inc di; di++
	ret
; 关闭文件，正常结束
finish:
; 调用中断21h(ah=3Eh)--关闭文件
	mov ah, 3Eh; BX = file handle
	mov bx, handle
	int 21h
	mov ah, 4Ch; AL = return code
	int 21h
; 打开文件失败，异常结束
err_finish:
; 调用中断21h(ah=09h)--输出错误提示语
	mov ah, 09h; DS:DX -> '$'-terminated string
	mov dx, offset err; err="Cannot open file!"
	int 21h
	mov ah, 4Ch; AL = return code
	mov al, 0
	int 21h
; ----------------函数---------------- End
code ends
end main