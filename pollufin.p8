pico-8 cartridge // http://www.pico-8.com
version 36
__lua__
-- init

-- to do
	-- randomise enemy type in
	-- infinite mode
	-- wait until parts to show
	-- game over
	

function _init()

	-- disable btnp repeat
	poke(0x5f00+92,255)

	states={menu=0,game=1,dead=2,
	inter=3}

	game_state=states.menu
	
	start_game()
	
	cam_offx=0
	cam_offy=-128
	cam_destx=0
	cam_desty=-128
	
	buy_hold=0
	
	-- time left to screen shake
	shake_time=0
	
	played_dead_sfx=false
	
end


function start_game()

	setup_spawns()

	setup_shop()
	
	init_player_stats()

	mk_plr()
	
	bullets={}
	
	particles={}
	
	bg_y=-127
	bg_spd=0.3
	
	enemies={}
	
end

-->8
-- update

function _update60()

	camera(cam_offx,cam_offy)

	if game_state==states.menu then
		menu_update()
	elseif game_state==states.game then
		game_update()
	elseif game_state==states.inter then
		inter_update()
	elseif game_state==states.dead then
		dead_update()
	end
	
end


function menu_update()

	cam_offy+=(sgn(cam_desty-cam_offy)*min(5,abs(cam_desty-cam_offy)))

	if btnp(❎) then
		start_game()
		cam_desty=0
	end
	
	-- transition finished
	if (cam_desty==0 and
	cam_offy==0) then
		game_state=states.game
	end
	
end


function game_update()

	plr:updt()
	
	bg_y+=bg_spd+enemy_spd/10
	if bg_y >= 0 then
		bg_y=-127
	end
	
	-- apply screenshake if
	-- required
	if shake_time>0 then
		shake_time-=1
		camera(cam_offx+rnd(6)-3,
		cam_offy+rnd(6)-3)
	end
	
	-- updating bullets
	for b in all(bullets) do
		local alive=b:updt()
		if not alive then
			del(bullets,b)
		end
	end
	
	-- updating particles
	for p in all(particles) do
		local alive=p:updt()
		if not alive then
			del(particles,p)
		end
	end
	
	-- updating enemies
	for e in all(enemies) do
		local alive=e:updt()
		if not alive then
			-- enemy death
			add_score(e.scr_val*scr_mult)
			money+=e.mny_val
			sfx(4,1)
			if e.type=="basic" then
				for i=1,15 do
					add(particles,
					mk_enemy_part(e.x+2+rnd(6),
					e.y+2+rnd(6)))
				end
			elseif e.type=="fast" then
				for i=1,25 do
					add(particles,
					mk_enemy_part(e.x+2+rnd(6),
					e.y+2+rnd(14)))
				end
			else
				for i=1,35 do
					add(particles,
					mk_enemy_part(e.x+2+rnd(6),
					e.y+2+rnd(6)))
				end
			end
			stg_kill+=1
			stg_dead+=1
			tot_kill+=1
			del(enemies,e)
		end
	end
	
	-- spawning enemy
	if (last_spawn>=min_delay and
	(total_spawned<enemies_total
	or infinite))
	then
		if(flr(rnd(spawn_chance+0.9))
		==spawn_chance) then
			-- spawn enemy
			total_spawned+=1
			last_spawn=0
			local en_type=flr(rnd(99.9)+
			1)
			if (en_type<=fast_chance) then
				-- fast enemy
				add(enemies,
				mk_fast_enemy(12+flr(
				rnd(3.9-min_lane)+min_lane
				)*32,0))
			elseif (en_type>fast_chance
			and en_type<=shield_chance+
			fast_chance) then
				-- shield enemy
				add(enemies,
				mk_shield_enemy(12+flr(
				rnd(3.9-min_lane)+min_lane
				)*32,8))
			else
				-- basic enemy
				add(enemies,
				mk_enemy(12+flr(rnd(3.9-
				min_lane)+min_lane)*32,8))
			end
		end
	end
	
	if not froze then
		last_spawn+=1
	end
	
	-- testing completion
	-- if complete switch to
	-- intermission state
	if (stg_dead==enemies_total 
	and not infinite and
	health>0) then
		game_state=states.inter
		cam_destx=128
		min_lane=0
		scr_mult=1
	end
	
	if (infinite and 
	stg_kill%50==0 and
	infinite_last_inter!=stg_kill)
	then
		infinite_last_inter=stg_kill
		game_state=states.inter
		cam_destx=128
		min_lane=0
		scr_mult=1
	end

end


function inter_update()

	-- camera transition
	cam_offx+=(sgn(cam_destx-cam_offx)*min(5,abs(cam_destx-cam_offx)))

	-- if transitioned back to
	-- game, leave inter state
	if (cam_destx==0 and
	cam_offx==0) then
		-- going back to game
		if not infinite then
			update_stage()
		else
			add_difficulty()
		end
		enemies={}
		particles={}
		game_state=states.game
	end

	-- if fully on menu
	if cam_offx==cam_destx then
		if btn(⬅️) then
			cam_destx=0
		end
		
		if (btnp(⬆️) and 
		shop_selected>1) then
			shop_selected-=1
		end
		if (btnp(⬇️) and
		shop_selected<#shop_items) then
			shop_selected+=1
		end
		
		if (btn(❎) and
		money>=
		shop_items[shop_selected]
		[2]+shop_items[shop_selected]
		[3]*shop_items[shop_selected]
		[4]) then
			buy_hold+=1
			camera(cam_offx+rnd(2)-1,
			cam_offy+rnd(2)-1)
		else
			buy_hold=0
		end
		
		if buy_hold>=60 then
			buy_hold=0
			local value=(
			shop_items[shop_selected][2]+
			shop_items[shop_selected][3]*
			shop_items[shop_selected][4])
			if (money>value and
			shop_items[shop_selected].
			buy()) then
				shop_items[shop_selected][4]+=1
				money-=value
				sfx(5,1)
			else
				sfx(6,1)
			end
		end
	end
	
end


function dead_update()

	if shake_time>0 then
		camera(cam_offx+rnd(6)-3,
		cam_offy+rnd(6)-3)
	end
	shake_time-=1
	
	-- finish updating particles
	for p in all(particles) do
		p:updt()
		local alive=p:updt()
		if not alive then
			del(particles,p)
		end
	end
	
	if (#particles==0 and
	not played_dead_sfx) then
		sfx(3,1)
		played_dead_sfx=true
	end

	if btnp(🅾️) then
		_init()
	end
end
-->8
-- draw

function _draw()

	cls()
	
	if game_state==states.menu then
		game_draw()
		menu_draw()
	elseif game_state==states.game then
		game_draw()
	elseif game_state==states.inter then
		-- draw game aswell so
		-- transition can occur
		game_draw()
		inter_draw()
	elseif game_state==states.dead then
		if #particles==0 then
			dead_draw()
		else
			game_draw()
		end
	end
	
end


function menu_draw()

	local map_bg=time()*10
	for i=0,4 do
		rectfill(i*32-map_bg%32,
		-128,i*32-map_bg%32+16,-1,3)
		rectfill(i*32-map_bg%32+16,
		-128,i*32-map_bg%32+32,-1,11)
	end
	
	map(0,17,29,-103+
	flr(sin(time()/1.7)*3.5),9,2)
	print("by jamzdev",
	32,-82+flr(sin(time()/1.7)*3.5),
	6)
	print("by jamzdev",
	32,-83+flr(sin(time()/1.7)*3.5),
	5)
	
	print("press ❎ to begin",
	32,-33+flr(cos(time()/1.7)*3.5)
	,1)
	print("press ❎ to begin",
	32,-34+flr(cos(time()/1.7)*3.5)
	,7)
	
end


function game_draw()

-- map drawing
	map(0,0,0,bg_y,16,16)
	map(0,0,0,bg_y+127,16,16)
	for i=1,3 do
		for e=2,15 do
			spr(35,i*32-1,e*8)
		end
	end
	
	-- particle drawing
	for p in all(particles) do
		p:draw()
	end
	
	-- object drawing
	plr:draw()
	
	for b in all(bullets) do
		b:draw()
	end
	
	for e in all(enemies) do
		e:draw()
	end
	
	
	-- lane block rectangle
	if min_lane!=0 then
		rectfill(0,0,30,127,5)
	end
	
	-- ui drawing
	rectfill(0,0,127,16,6)
	rect(0,0,127,16,7)
	for i=0,4 do
		spr(52,3+i*10,8)
	end
	for i=0,health-1 do
		spr(36,3+i*10,8)
	end

	print("score:"..scr_str(),3,
	2,5)
	spr(37,55,2)
	print(money,60,3,5)
	
	if not infinite then
		print("stage "..stage,80,3,5)
		print(flr(stg_kill/
		enemies_total*100).."%",80,
		10,5)
	else
		print("infinite",80,3,5)
		print(stg_kill.." kills",
		80,10,5)
	end
	
end


function inter_draw()
	rectfill(127,0,254,127,5)
	if not infinite then
		print("stage "..stage..
		" complete!",158,
		12+flr(sin((time()-0.1)/1.3)
		*3.5),11)
		print("stage "..stage..
		" complete!",158,
		12+flr(sin(time()/1.3)*3.5),7)
	else
		print("shop break",173,
		12+flr(sin((time()-0.1)/1.3)
		*3.5),11)
		print("shop break",173,
		12+flr(sin(time()/1.3)*3.5),7)
	end
	print(
	"press ⬅️ to continue",
	153,110+flr(cos((time()-0.08)
	/1.3)*2.4),9)
	print(
	"press ⬅️ to continue",
	153,110+flr(cos(time()/1.3)*2.4
	),7)
	
	print("you have",168,35,7)
	spr(37,202,33)
	print(money,207,35,7)
	
	for i=0,#shop_items-1 do
		rectfill(183,45+i*14,194,
		56+i*14,1)
		if shop_selected-1==i then
			rect(182,44+i*14,195,
			57+i*14,7)
			print(shop_items[i+1][1],
			180-#shop_items[i+1][1]*4,
			49+i*14,7)
			print(shop_items[i+1][2]+
			shop_items[i+1][3]*
			shop_items[i+1][4],
			203,49+i*14,7)
			spr(37,198,47+i*14)
		end
		spr(shop_items[i+1][5],
		185,47+i*14)
	end
	
	-- only draw buy bar if
	-- can afford
	if (money>=
	shop_items[shop_selected]
	[2]+shop_items[shop_selected]
	[3]*shop_items[shop_selected]
	[4]) then
		rect(174,90,204,100,1)
		rectfill(174,90,174+buy_hold/2,
		100,1)
		print("❎ buy",177,93,6)
	end
	
end


function dead_draw()

	print("game over!",46,
	20+flr(sin((time()-0.1)/1.3)
	*3.5),8)
	print("game over!",46,
	20+flr(sin(time()/1.3)*3.5),7)
	
	print("score"
	,54,50+
	flr(cos((time()-0.1)/1.3)*
	2.1),12)
	print("score",54,
	50+flr(cos(time()/1.3)*2.1),7)
	
	--local scr_x=0
	--if #scr_str()%2==0 then
		--scr_x=64-#scr_str()/2*4
	--else
		--scr_x=62-flr(#scr_str()/2)
	--end
	local scr_x=62
	if (#scr_str()%2==0) scr_x=64
	print(scr_str(),scr_x-
	flr(#scr_str()/2)*4,60+
	flr(cos((time()-0.1)/1.3)*
	2.1),12)
	print(scr_str(),scr_x-
	flr(#scr_str()/2)*4,60+
	flr(cos(time()/1.3)*
	2.1),7)
	
	print(
	"press 🅾️ to return to menu",
	13,85+flr(cos((time()-0.08)
	/1.3)*2.4),9)
	print(
	"press 🅾️ to return to menu",
	13,85+flr(cos(time()/1.3)*2.4
	),7)
	
end
-->8
-- player

function mk_plr()

	plr={}
	
	plr.x=0
	plr.y=112
	plr.lane=0
	plr.x=12+plr.lane*32
	plr.destx=plr.x
	
	plr.spr=18
	
	-- allows bullet to be shot
	-- during transition
	-- prevents unresponsive feel
	plr.queue_blt=false
	
	function plr.updt(s)
	
		plr.spr=18
		if s.x==s.destx then
			if btnp(➡️) and
			s.lane<3 then
				s.lane+=1
				s.destx=12+s.lane*32
			end
			if btnp(⬅️) and
			s.lane>min_lane then
				s.lane-=1
				s.destx=12+s.lane*32
			end
			
			if (btnp(❎) or 
			s.queue_blt) then
				add(bullets,
				mk_bullet(s.x,s.y-2))
				s.queue_blt=false
			end
		else
			-- transition
			s.x+=(sgn(s.destx-s.x)
			*min(4+enemy_spd/2,
			abs(s.destx-s.x)))
			if btnp(❎) then
				s.queue_blt=true
			end
			-- trail effect
			-- and turn sprite
			if s.destx-s.x!=0 then
				add(particles,
				mk_plr_trail(s.x+4+
				sgn(s.destx-s.x)*-6,
				s.y+6,-sgn(s.destx-s.x)))
				plr.spr=18+sgn(s.destx-s.x)
			end
		end
		
		-- toggling freeze
		if btnp(🅾️) then
			if (not froze and 
			health>1) then
				shake_time=15
				froze=true
				freeze_time=max_freeze_time
				health-=1
				sfx(8,1)
			else
				sfx(0,1)
			end
		end
		
		freeze_time-=1
		if freeze_time<=0 then
			froze=false
		end
		------------------
		
		-- leaving blocked lane
		-- if in it after purchase
		if s.lane<min_lane then
			s.lane=min_lane
			s.x=12+s.lane*32
			s.destx=12+s.lane*32
		end
			
	end
	
	function plr.draw(s)
		spr(plr.spr,s.x,s.y)
	end
	
end
-->8
-- objects

-- bullet
function mk_bullet(_x,_y)

	local b={}
	b.x=_x
	b.y=_y
	b.spd=2
	
	b.col=mk_colbox(b.x+3,b.y,
	b.x+4,b.y+3)
	
	function b.updt(s)
	
		s.y-=s.spd
		if s.y<8 then
			return false
		end
		
		s.col:updt(s.x+3,s.y,s.x+4,
		s.y+3)
		
		return true
	end
	
	function b.draw(s)
		spr(2,s.x,s.y)
	end
	
	return b
	
end


-- basic enemy
function mk_enemy(_x,_y)
	
	local e={}
	e.x=_x
	e.y=_y
	e.col=mk_colbox(e.x+1,e.y,
	e.x+6,e.y+6)
	e.scr_val=(flr(rnd(kill_scr
	/2))+kill_scr)
	e.mny_val=(flr(rnd(1.9))+1+
	flr(kill_scr/20))
	e.last_froze_part=0
	e.type="basic"
	
	function e.updt(s)
	
		if not froze then
			s.y+=enemy_spd
			s.col:updt(s.x+1,s.y,s.x+6,
			s.y+6)
		end
		
		if (froze and
		s.last_froze_part>5) then
			s.last_froze_part=0
			add(particles,mk_freeze(
			s.x+rnd(8),s.y+rnd(8)))
		end
		s.last_froze_part+=1
		
		if s.y>127 then
			del(enemies,e)
			stg_dead+=1
			take_health()
			shake_time=10
			for i=1,20 do
				add(particles,
				mk_escape(s.x,s.y))
			end
			sfx(1,1)
		end
		
		-- test collision
		for b in all(bullets) do
			if s.col:test(b.col) then
				del(bullets,b)
				return false
			end
		end
		
		return true
	end
	
	function e.draw(s)
		if froze then
			spr(4,s.x,s.y)
		else
			spr(3,s.x,s.y)
		end
	end
	
	return e
	
end


-- fast enemy
function mk_fast_enemy(_x,_y)

	local e={}
	e.x=_x
	e.y=_y
	e.col=mk_colbox(e.x+1,e.y,
	e.x+6,e.y+14)
	e.scr_val=(flr(rnd(kill_scr
	))+kill_scr)
	e.mny_val=(flr(rnd(1.9))+2+
	flr(kill_scr/10))
	e.last_froze_part=0
	e.type="fast"
	
	function e.updt(s)
	
		if not froze then
			s.y+=enemy_spd*1.5
			s.col:updt(s.x+1,s.y,s.x+6,
			s.y+14)
		end
		
		if (froze and
		s.last_froze_part>5) then
			s.last_froze_part=0
			add(particles,mk_freeze(
			s.x+rnd(8),s.y+rnd(16)))
		end
		s.last_froze_part+=1
		
		if s.y>127 then
			del(enemies,e)
			stg_dead+=1
			take_health()
			shake_time=10
			for i=1,20 do
				add(particles,
				mk_escape(s.x,s.y))
			end
			sfx(1,1)
		end
		
		-- test collision
		for b in all(bullets) do
			if s.col:test(b.col) then
				del(bullets,b)
				return false
			end
		end
		
		return true
	end
	
	function e.draw(s)
		if froze then
			spr(6,s.x,s.y)
			spr(22,s.x,s.y+8)
		else
			spr(5,s.x,s.y)
			spr(21,s.x,s.y+8)
		end
	end
	
	return e

end

-- shielded enemy
function mk_shield_enemy(_x,_y)

	local e={}
	e.x=_x
	e.y=_y
	e.col=mk_colbox(e.x+1,e.y,
	e.x+6,e.y+6)
	e.scr_val=(flr(rnd(kill_scr*2
	))+kill_scr)
	e.mny_val=(flr(rnd(1.9))+3+
	flr(kill_scr/5))
	e.last_froze_part=0
	e.type="shield"
	e.health=5
	e.flash=0
	
	function e.updt(s)
	
		if not froze then
			s.y+=enemy_spd*0.3
			s.col:updt(s.x+1,s.y,s.x+6,
			s.y+6)
		end
		
		if (froze and
		s.last_froze_part>5) then
			s.last_froze_part=0
			add(particles,mk_freeze(
			s.x+rnd(8),s.y+rnd(8)))
		end
		s.last_froze_part+=1
		
		if s.y>127 then
			del(enemies,e)
			stg_dead+=1
			take_health(2)
			shake_time=20
			for i=1,20 do
				add(particles,
				mk_escape(s.x,s.y))
			end
			sfx(1,1)
		end
		
		s.flash-=1
		
		-- test collision
		for b in all(bullets) do
			if s.col:test(b.col) then
				del(bullets,b)
				s.health-=1
				if s.health<=0 then
					return false
				else
					sfx(7,2)
					s.flash=4
					for i=1,5 do
						add(particles,
						mk_metal(s.x+rnd(8),
						s.y+rnd(8)))
					end
				end
			end
		end
		
		return true
	end
	
	function e.draw(s)
		if froze then
			spr(4,s.x,s.y)
		else
			spr(3,s.x,s.y)
		end
		spr(11-s.health+1,s.x,s.y)
		if s.flash>0 then
			spr(23,s.x,s.y)
		end
	end
	
	return e

end


-- enemy die particle
function mk_enemy_part(_x,_y)
	
	local p={}
	p.x=_x
	p.y=_y
	p.col=11
	if (rnd(2)<1) p.col=3
	if (rnd(5)>4) p.col=8
	local dir=rnd(1)
	local spd=rnd(0.4)+0.2
	p.dx=cos(dir)*spd
	p.dy=sin(dir)*spd
	p.rad=rnd(4.5)+1
	p.decay=rnd(0.2)+0.05
	
	function p.updt(s)
		s.x+=s.dx
		s.y+=s.dy
		s.rad-=s.decay
		if s.rad<=0 then
			return false
		end
		return true
	end
	
	function p.draw(s)
		circfill(s.x,s.y,s.rad,s.col)
	end
	
	return p
	
end


-- enemy freeze particle
function mk_freeze(_x,_y)
	
	local p={}
	p.x=_x
	p.y=_y
	p.col=12
	if (rnd(5)>4) p.col=7
	local dir=rnd(1)
	local spd=rnd(0.3)+0.1
	p.dx=cos(dir)*spd
	p.dy=sin(dir)*spd
	p.rad=rnd(5)+1.5
	p.decay=rnd(0.15)+0.03
	
	function p.updt(s)
		s.x+=s.dx
		s.y+=s.dy
		s.rad-=s.decay
		if s.rad<=0 then
			return false
		end
		return true
	end
	
	function p.draw(s)
		circfill(s.x,s.y,s.rad,s.col)
	end
	
	return p
	
end


-- enemy escape particle
function mk_escape(_x,_y)

	local p={}
	p.x=_x
	p.y=_y
	p.col=8
	if (rnd(5)>3) p.col=9
	local dir=rnd(0.6)-0.3
	local spd=rnd(0.4)+0.15
	p.dx=cos(dir)*spd
	p.dy=sin(dir)*spd
	p.rad=rnd(5)+1.5
	p.decay=rnd(0.15)+0.05
	
	function p.updt(s)
		s.x+=s.dx
		s.y+=s.dy
		s.rad-=s.decay
		if s.rad<=0 then
			return false
		end
		return true
	end
	
	function p.draw(s)
		circfill(s.x,s.y,s.rad,s.col)
	end
	
	return p

end

-- shield enemy metal particles
function mk_metal(_x,_y)

	local p={}
	p.x=_x
	p.y=_y
	p.col=5+flr(rnd(1.9))
	local dir=rnd(1)
	local spd=rnd(0.45)+0.25
	p.dx=cos(dir)*spd
	p.dy=sin(dir)*spd
	p.rad=rnd(4)+1
	p.decay=rnd(0.25)+0.05
	
	function p.updt(s)
		s.x+=s.dx
		s.y+=s.dy
		s.rad-=s.decay
		if s.rad<=0 then
			return false
		end
		return true
	end
	
	function p.draw(s)
		circfill(s.x,s.y,s.rad,s.col)
	end
	
	return p
	
end

-- player trail particles
-- _d is x dir of velocity
function mk_plr_trail(_x,_y,_d)
	
	local p={}
	p.x=_x
	p.y=_y
	local dir=rnd(0.3)+0.1
	local spd=rnd(0.2)+0.2
	p.dx=cos(dir)*_d*spd
	p.dy=sin(dir)*spd
	p.rad=rnd(3)+1
	p.decay=rnd(0.15)+0.05
	p.col=6-flr(rnd(1.6))
	
	function p.updt(s)
		s.x+=s.dx
		s.y+=s.dy
		s.rad-=s.decay
		if s.rad<=0 then
			return false
		end
		return true
	end
	
	function p.draw(s)
		circfill(s.x,s.y,s.rad,s.col)
	end
	
	return p
	
end
-->8
-- collision

function mk_colbox(_x1,_y1,
_x2,_y2)

	local col={}
	col.x1=_x1
	col.y1=_y1
	col.x2=_x2
	col.y2=_y2
	
	-- test collision with
	-- other collider
	function col.test(s,other)
		return (
		s.x1 < other.x2 and
		s.x2 > other.x1 and
		s.y1 < other.y2 and
		s.y2 > other.y1
		)
	end
	
	function col.updt(s,_x1,_y1,
	_x2,_y2)
		s.x1=_x1
		s.x2=_x2
		s.y1=_y1
		s.y2=_y2
	end
	
	return col
	
end
-->8
-- gameplay management

function init_player_stats()

	health=3
	money=0
	
	-- freeze power
	max_freeze_time=160
	freeze_time=0
	froze=false
	---------------
	
	-- stage info
	stage=0
	enemies_total=0
	total_spawned=0
	enemy_spd=0
	kill_scr=0
	spawn_chance=0
	min_delay=0
	fast_chance=0
	shield_chance=0
	update_stage()
	
	last_spawn=0
	-------------
	
	-- infinite mode
	infinite=false
	infinite_last_inter=0
	----------------
	
	stg_kill=0
	stg_dead=0
	tot_kill=0
	
	-- lane remove
	min_lane=0
	
	score={"0","0"}
	scr_mult=1
	
end


-- allows score larger than
-- 16 bit integer
function add_score(num)
	score[1]+=num
	if score[1]>9999 then
		score[2]+=1
		score[1]-=9999
	end
	if score[2]!="0" then
		local ad=""
		for i=0,3-#tostr(score[1]) do
			ad=ad.."0"
		end
		score[1]=ad..score[1]
	end
end

-- converts score int in table
-- into correct string form
function scr_str()
	local scr=""
	for i=#score,1,-1 do
		if i==1 or score[i]!="0" then
			scr=scr..score[i]
		end
	end
	return scr
end


function setup_shop()
	shop_selected=1
	-- shop items
	-- {name,base_price,
	--		price_increment,
	--		num_purchased,
	--  spr_icon,purchase_func}
	shop_items={
		{"+1 life",40,40,0,36,
		buy=function()
			if health<5 then
				health+=1
				return true
			end
			return false
		end},
		{"lane block",150,100,0,38,
		buy=function()
			if min_lane!=1 then
				min_lane=1
				return true
			end
			return false
		end},
		{"2x score",100,50,0,53,
		buy=function()
			if scr_mult!=2 then
				scr_mult=2
				return true
			end
			return false
		end}
	}
end


function take_health(h)

	h=h or 1
	health-=h
	if health<=0 then
		game_state=states.dead
		shake_time=10
	end

end

-- enemy spawn control
function setup_spawns()
	-- each stage has format
	-- {spawns,move_speed,
	--  min_delay,spawn_chance,scr,
	--		fast_chance,shield_chance}
	stage_spawns={
		{20+flr(rnd(5)),0.7,40,15,5,
		0,0},
		{30+flr(rnd(10)),0.8,35,20,8,
		5,0},
		{35+flr(rnd(15)),0.9,30,13,12,
		10,0},
		{45+flr(rnd(15)),1,25,15,18,
		15,5},
		{60+flr(rnd(15)),1.05,20,15,25,
		15,5},
		{70+flr(rnd(15)),1.1,15,15,30,
		15,10},
		{80+flr(rnd(15)),1.15,15,10,40,
		20,10},
		{80+flr(rnd(20)),1.2,15,10,55,
		25,10},
		{90+flr(rnd(20)),1.3,15,15,65,
		25,10},
		{100+flr(rnd(20)),1.3,15,15,80,
		30,15}
	}
end

-- updating globals based on
-- current stage data in table
function update_stage()
	stage+=1
	stg_kill=0
	stg_dead=0
	if stage>#stage_spawns then
		infinite=true
	else
		total_spawned=0
		last_spawn=0
		enemies_total=stage_spawns
		[stage][1]
		enemy_spd=stage_spawns
		[stage][2]
		min_delay=stage_spawns
		[stage][3]
		spawn_chance=stage_spawns
		[stage][4]
		kill_scr=stage_spawns
		[stage][5]
		fast_chance=stage_spawns
		[stage][6]
		shield_chance=stage_spawns
		[stage][7]
	end
end

-- add diffiiculty in infinite
function add_difficulty()
	enemy_spd=max(enemy_spd+0.05,
	1.6)
	min_delay=min(min_delay-0.5,
	8)
	spawn_chance=min(spawn_chance
	-0.3,9)
	kill_scr+=10
	fast_chance=clmp(fast_chance+
	rnd(8)-4,25,35)
	shield_chance=clmp(
	shield_chance+rnd(6)-3,10,
	20)
end

function clmp(v,mn,mx)
	return max(min(v,mx),mn)
end
__gfx__
000000000000000000086000032b82300d2c82d0032b82300d2c82d005d66d5005d6605005d66050050600500000000000000000000000000000000000000000
0000000000000000000a90000033330000dddd0003bbbb300dccccd0005555000055550000055500000055000000000011000111111101111000111100001110
0070070000000000000a90000332b3300dd2cdd00032b30000d2cd00055665500506650005066000050600000000000071101177777111771000177100011710
0007700000000000000a9000038bb2300d8cc2d0003b830000dc8d0005dddd5005dddd5000dd005000d000500000000077111777777711771000177100017710
000770000000000000000000032b8b300d2c8cd0003b230000dc2d00056666500066665000006050000060500000000077711776667711771000177100017710
0070070000000000000000000372b7300d72c7d0032bbb300d2cccd0050550500505505005055000050000000000000067711771117711771000177100017710
000000000000000000000000031bb1300d1cc1d003b2b8300dc2c8d0050660500506600000066000000600000000000077711771017711771000177100017710
0000000000000000000000000033330000dddd00038bb2300d8cc2d0005555000050550000005000000050000000000077611771017711771000177100017710
0000000000008000000880000008000000000000032bbb300d2cccd0077777700000000000000000000000000000000076111771017711771000177100017710
000000000008280000822800008280000000000003bbb2300dccc2d0007777000000000000000000000000000000000061101771017711771000177100017710
0000000000026200022662200026200000000000038b2b300d8c2cd0077777700000000000000000000000000000000011001771017711771000177100017710
000000000056655005666650055665000000000003bbb8300dccc8d0077777700000000000000000000000000000000000001771117711771111177111117711
00000000005cc65056cccc65056cc50000000000038b2b300d8c2cd0077777700000000000000000000000000000000000001777777711777771177777117777
0000000000511c505c1111c505c11500000000000378b7300d78c7d0077777700000000000000000000000000000000000001677777611777771177777116777
0000000000511150511111150511150000000000031bb1300d1cc1d0077777700000000000000000000000000000000000001166666111666661166666111666
00000000000555000555555000555000000000000033330000dddd00007777000000000000000000000000000000000000000111111101111111111111101111
00000000111111111111100167600000022002203330000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000111111111111033067600000288228823730000000000b00000000000000000000000000000000000011111111101111111111111111111101111000
00000000111111111111103067600000287888823b300000000b0b00000000000000000000000000000000000017777717111777777117777771177111771000
00000000101111111111103067600000288888823b300000000b0000000000000000000000000000000000000017777717711777777117777771177711771000
00000000030111111111111167600000028888203b30000008888880000000000000000000000000000000000017766617711776666116677661177771771000
00000000030111111111111167600000002882003b30000008666680000000000000000000000000000000000017711117711771111111177111177777771000
00000000111111111111111167600000000220003b30000008666680000000000000000000000000000000000017711117711777710000177100177677771000
00000000111111111111111167600000000000003330000008888880000000000000000000000000000000000017777717711777710000177100177167771000
00000000111111111111111100000000022002200000000000000000000000000000000000000000000000000017777717711776610000177100177116771000
00000000111011111111111100000000222222220bbb000000000000000000000000000000000000000000000017766617711771110000177100177111771000
00000000110b01111111111100000000222222220b0b000000000000000000000000000000000000000000000017711117711771000000177100177101771000
0000000011033011111111110000000022222222000b0b0b00000000000000000000000000000000000000000017710017711771000011177111177101771000
00000000110301111111111100000000022222200bbb00b000000000000000000000000000000000000000000017710077711771000017777771177101771000
00000000111111111111111100000000002222000b000b0b00000000000000000000000000000000000000000017710077611771000017777771177101771000
00000000111111111111111100000000000220000bbb000000000000000000000000000000000000000000000016610066111661000016666661166101661000
00000000111111111111111100000000000000000000000000000000000000000000000000000000000000000011110011101111000011111111111101111000
__label__
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333311111111bbb1111111b111133311113333111b111b111111111111111111113111133bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb33333333333177777711b117777711177133317713331171b1711177777711777777117711177133bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb333333333331777777711177777771177133317713331771b1771177777711777777117771177133bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb333333333331776667771177666771177133317713331771b1771177666611667766117777177133bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb333333333331771116771177111771177133317713331771b1771177111111117711117777777133bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333317711177711771b1771177133317713331771b1771177771bbbb17713317767777133bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333317777777611771b1771177133317713331771b1771177771bbbb17713317716777133bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333317777776111771b1771177133317713331771b1771177661bbbb17713317711677133bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb33333333333177666611b1771b1771177133317713331771b1771177111bbbb17713317711177133bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333317711111bb1771b1771177133317713331771b17711771bbbbbb17713317713177133bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333317713bbbbb177111771177111117711111771117711771bbbb1117711117713177133bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333317713bbbbb177777771177777117777711777777711771bbbb1777777117713177133bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333317713bbbbb167777761177777117777711677777611771bbbb1777777117713177133bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333316613bbbbb116666611166666116666611166666111661bbbb1666666116613166133bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333311113bbbbbb1111111b1111111111111131111111b1111bbbb1111111111113111133bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb33333333333355535b5bbbbb555b555b55535553553355535b5bbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb33333333333356535b5bbbbb656b565b55536653565356635b5bbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333335563555bbbbbb5bb555b56533563535355335b5bbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333335653665bbbbbb5bb565b5353563353535633555bbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333335553555bbbbb55bb5b5b5353555355535553656bbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333336663666bbbbb66bb6b6b6363666366636663b6bbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333337773777b777bb77bb77b3333377777333333777bb77bbbbb777b7773377377737733bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333337173717b711b711b711b3333771717733333171b717bbbbb717b7113711317137173bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333337773771b77bb777b777b3333777177733333b7bb7b7bbbbb771b7733733337337373bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333337113717b71bb117b117b3333771717733333b7bb7b7bbbbb717b7133737337337373bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb33333333333373337b7b777b771b771b3333177777133333b7bb771bbbbb777b7773777377737373bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb33333333333313331b1b111b11bb11bb3333311111333333b1bb11bbbbbb111b1113111311131313bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333
3333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb3333333333333333bbbbbbbbbbbbbbbb333333333333

__map__
3232213221213232213221322132323200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2132323232323232323232323221322100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2132323232323232223232323232323200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3232213232323232323232323232323200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3232323221323232323232323232323200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3232323232323232322132323232323200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3232322132323232323232323232323200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3232323232323232323232323232322100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3232323232323232323232323232213200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121323232323232323231323221213200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2132223232323232323221323232323200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3232323232323231322132323232323200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3232323222323232323232323232322100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3232323232323232213232323232323200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3232323222323231323232323232322200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3222313221323232213232322122323200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2b0c0d0e0f2c2d2e2f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3b1c1d1e1f3c3d3e3f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010c0000020540b050020550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010900001064510645000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011300200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0913000017050150501305000000100500f0500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300001c054100501705010050160501c0550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800001c0552004020035160001c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a000014050120500f0500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010c00001064513640176450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000002c6201c6301c6352400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
