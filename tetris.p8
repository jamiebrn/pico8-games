pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

function _init()
	grid={}
	for y=0,17 do
		local gridrow={}
		for x=0,9 do
			add(gridrow,0)
		end
		add(grid,gridrow)
	end
	
	gdx=34
	gdy=10
	
	rowflsh={}
	flsht=0.2
	
	scr=0
	lnes=0
	over=false
	lvl=1
	
	pnxt=flr(rnd(7))
	rstpiece()
end

function rstpiece()
	ppos={4,0}
	ptyp=pnxt
	pnxt=flr(rnd(7))
	prot=0
	ptick=0
	
	if (piececol(ppos[1],ppos[2],
		ptyp,prot)) then
		over=true
		sfx(1)
	end
end

function _update60()
	if (not over) then
		uptgame()
	else
		if btnp(❎) then
			_init()
		end
	end
end

function uptgame()
	ptick+=lvl
	if btn(⬇️) then
		ptick+=15
	end
	if ptick>=60 then
		if (not mvdown()) then
			rstpiece()
			sfx(3)
		end
	end
	
	if btnp(⬅️) then
		mvx(-1)
	end
	if btnp(➡️) then
		mvx(1)
	end
	if btnp(⬆️) then
		while (mvdown()) do end
		rstpiece()
		sfx(2)
	end
	if btnp(🅾️) then
		rtpiece(-1)
	end
	if btnp(❎) then
		rtpiece(1)
	end
	
	for y,row in pairs(rowflsh) do
		row[2]-=1/60
		if (row[2]<=0) then
			deli(rowflsh,y)
		end
	end
end

function mvdown()
	local sx=ptyp*8+(prot%2)*4
	local sy=8+flr(prot/2)*4
	for y=0,3 do
		for x=0,3 do
			local c=sget(sx+x,sy+y)
			if (c!=0) then
				if (ppos[2]+y>=#grid-1) then
					placepiece()
					return false
				end
				if ((grid[ppos[2]+y+2]
					[ppos[1]+x+1])!=0) then
					placepiece()
					return false
				end
			end
		end
	end

	ppos[2]+=1
	ptick=0
	return true
end

function mvx(dx)
	if (ppos[1]+dx<0 or
		ppos[1]+dx>#grid[1]-1) then
		return false
	end
	
	if (piececol(ppos[1]+dx,
		ppos[2],ptyp,prot)) then
		return false
	end
	
	ppos[1]+=dx
	return true
end

function rtpiece(drt)
	local nrt=((prot+drt)%4+4)%4
	if (piececol(ppos[1],ppos[2],
		ptyp,nrt)) then
		return false
	end
	
	prot=nrt
	return true
end

function piececol(px,py,typ,rot)
	local sx=typ*8+(rot%2)*4
	local sy=8+flr(rot/2)*4
	for y=0,3 do
		for x=0,3 do
			local c=sget(sx+x,sy+y)
			if (c!=0) then
				if (grid[py+y+1]
					[px+x+1]!=0) then
					return true
				end
			end
		end
	end
	return false
end

function placepiece()
	local sx=ptyp*8+(prot%2)*4
	local sy=8+flr(prot/2)*4
	for y=0,3 do
		for x=0,3 do
			local c=sget(sx+x,sy+y)
			if (c!=0) then
				grid[ppos[2]+1+y]
					[ppos[1]+1+x] = c
			end
		end
	end
	
	lineclr()
end

function lineclr()
	local total=0
	for y,row in pairs(grid) do
		local full=true
		for block in all(row) do
			if (block==0) then
				full=false
				break
			end
		end
		if full then
			for ry=y,2,-1 do
				grid[ry]=grid[ry-1]
			end
			for x=1,#grid[1] do
				grid[1][x]=0
			end
			add(rowflsh,{y-1,flsht})
			total+=1
		end
	end
	lnes+=total
	scr+=flr(15*total^2)
	
	if total>0 then
		sfx(0)
		if (lnes%10==0) then
			lvl+=1
			sfx(4)
		end
	end
end

function _draw()
	cls()
	
	drawgrid()
	drawpiece(ppos[1],ppos[2],
		ptyp,prot)
	drawrowflsh()
	
	print("next",105,7,7)
	drawpiece(12,1,pnxt,0)
	
	print("score",105,50,7)
	print(scr,105,57,7)
	print("lines",105,70,7)
	print(lnes,105,77,7)
	print("level",105,90,7)
	print(lvl,105,97,7)
	
	if (over) then
		print("game over!",44,60,7)
		print("❎ to restart",38,70,7)
	end
end
-->8
function drawgrid()
	rectfill(gdx-5,gdy-5,gdx+
	(#grid[1])*6-1+5,gdy+
	(#grid)*6-1+5,1)

	rectfill(gdx,gdy,gdx+
	(#grid[1])*6-1,gdy+
	(#grid)*6-1,5)

	for y,row in pairs(grid) do
		for x,block in pairs(row) do
			if (block!=0) then
				drawblock(x-1,y-1,block)
			end
		end
	end
end

function drawpiece(px,py,typ,
	rot)
	local sx=typ*8+(rot%2)*4
	local sy=8+flr(rot/2)*4
	for y=0,3 do
		for x=0,3 do
			local c=sget(sx+x,sy+y)
			if (c!=0) then
				drawblock(px+x,
					py+y,c)
			end
		end
	end
end

function drawblock(gx,gy,c)
	rectfill(gdx+(gx)*6,gdy+(gy)*6,
					gdx+(gx)*6+5,gdy+(gy)*6+5,
					c)
	spr(1,gdx+(gx)*6,gdy+(gy)*6)
end

function drawrowflsh()
	for row in all(rowflsh) do
		rectfill(gdx+#grid[1]*6*0.5*
			(1-row[2]/flsht),gdy+row[1]*6+6*
			0.5*
			(1-row[2]/flsht),gdx
			+#grid[1]*6*(1-0.5*
			(1-row[2]/flsht)),
			gdy+row[1]*6+6-6*0.5*
			(1-row[2]/flsht),7)
	end
end
__gfx__
00000000111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000100001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700100001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000100001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000100001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
aa00aa00400044440220200099000900800088800c00c000bbb00b00000000000000000000000000000000000000000000000000000000000000000000000000
aa00aa00400000002200220009909900800080000c00ccc00b00bb00000000000000000000000000000000000000000000000000000000000000000000000000
0000000040000000000002000000900088000000cc00000000000b00000000000000000000000000000000000000000000000000000000000000000000000000
00000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
aa00aa0040004444022020009900090088000080cc00ccc00b00b000000000000000000000000000000000000000000000000000000000000000000000000000
aa00aa0040000000220022000990990008008880c00000c0bbb0bb00000000000000000000000000000000000000000000000000000000000000000000000000
0000000040000000000002000000900008000000c00000000000b000000000000000000000000000000000000000000000000000000000000000000000000000
00000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00010000000000412004120041200412004120041200512005120061200712008120091200b1200c1200d1200d1200d1200f1200f120081000810008100081000810008100081000810008100081000910009100
00130000113200e3200d3200a32005320053200532000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000030500205006050080500a0500b0500d05015300163000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000a05009050070500505000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000805005050080500c0500c050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
