program Minesweeper;

uses
	termio;

type
	TField = record
				w, h, cx, cy: integer;
				cells, open, flags: array of array of boolean;
			 end;

procedure fieldRandom(var field: TField; bperc: integer);
var
	i, x, y: integer;
begin
	i := 0; repeat
		x := random(field.w+1);
		y := random(field.h+1);
		if field.cells[x][y] then continue;
		field.cells[x][y] := true;
		inc(i)
	until i = ((field.w+1)*(field.h+1)*bperc) div 100
end;

procedure fieldMoveMineRand(var field: TField; x,y: integer);
var
	i, j, k: integer;
begin
	for k := 0 to 1000 do
	begin
		i := random(field.w+1);
		j := random(field.h+1);
		if not field.cells[i][j] then
		begin
			field.cells[i][j] := true;
			field.cells[x][y] := false;
			exit
		end
	end
end;

procedure fieldSetup(var field: TField; w,h,bperc: integer);
var
	i, j: integer;
begin
	setLength(field.cells, w+1, h+1);
	setLength(field.open, w+1, h+1);
	setLength(field.flags, w+1, h+1);
	field.w := w;
	field.h := h;
	field.cx := 0;
	field.cy := 0;
	fieldRandom(field, bperc);
	for i := 0 to w do
		for j := 0 to h do
		begin
			field.open[i][j] := false;
			field.flags[i][j] := false
		end
end;

function fieldNbors(var field: TField; x,y: integer): integer;
var
	i, j: integer;
begin
	fieldNbors := 0;
	for i := x-1 to x+1 do
		for j := y-1 to y+1 do
			if (i>=0) and (i<=field.w) and
			   (j>=0) and (j<=field.h) and
			   ((i<>x) or (j<>y)) then
				if field.cells[i][j] then inc(fieldNbors)
end;

function fieldNborFlags(var field: TField; x,y: integer): integer;
var
	i, j: integer;
begin
	fieldNborFlags := 0;
	for i := x-1 to x+1 do
		for j := y-1 to y+1 do
			if (i>=0) and (i<=field.w) and
			   (j>=0) and (j<=field.h) and
			   ((i<>x) or (j<>y)) then
				if field.flags[i][j] then inc(fieldNborFlags)
end;

procedure fieldOpenMines(var field: TField);
var
	i, j: integer;
begin
	for i := 0 to field.w do
		for j := 0 to field.h do
			if field.cells[i][j] then
				field.open[i][j] := true
end;

function fieldOpen(var field: TField; x,y: integer; force: boolean): boolean;
var
	i, j: integer;
begin
	fieldOpen := false;
	if (x>=0) and (x<=field.w) and
	   (y>=0) and (y<=field.h) then
		if (not field.open[x][y] or force) and not field.flags[x][y] then
		begin
			field.open[x][y] := true;
			if field.cells[x][y] then
			begin
				fieldOpen := true;
				exit
			end;

		    if (fieldNbors(field, x, y)<=fieldNborFlags(field, x, y)) then
				for i := x-1 to x+1 do
					for j := y-1 to y+1 do
						if (i<>x) or (j<>y) then
						begin
							fieldOpen := fieldOpen(field, i, j, false);
							if fieldOpen then exit
						end
		end
end;

function fieldClosed(var field: TField): integer;
var
	i, j: integer;
begin
	fieldClosed := 0;
	for i := 0 to field.w do
		for j := 0 to field.h do
			if not field.open[i][j] then
				inc(fieldClosed)
end;

procedure fieldPrint(var field: TField);
var
	i, j, n: integer;
begin
	for j := 0 to field.h do
	begin
		for i := 0 to field.w do
		begin
			if field.open[i][j] then
				if field.cells[i][j] then write(chr(27), '[31m*')
				else begin
					n := fieldNbors(field, i, j);
					case n of
						0: begin write(' '); continue end;
						1: write(chr(27), '[94m');
						2: write(chr(27), '[32m');
						3: write(chr(27), '[31m');
						4: write(chr(27), '[35m');
						5: write(chr(27), '[31m');
						6: write(chr(27), '[36m');
						7: write(chr(27), '[94m');
						8: write(chr(27), '[33m');
					end;
					write(n)
				end
			else if field.flags[i][j] then write(chr(27), '[91mF')
			else write('#');
			write(chr(27), '[39m')
		end;
		writeln
	end
end;

procedure exitWErr(s: string);
begin
	writeln(s);
	halt
end;

var
	field: TField;
	origTerm, term: TTermios;
	buff: char;
	lost, esc, won, first: boolean;
	bperc, fw, fh, valCode, bombc: integer;
begin
	if ParamCount<>3 then
		exitWErr('Usage: minesweeper <width> <height> <bomb-percentage>' +chr(10)+
				  'Move: WASD'										 	 +chr(10)+
				  'Open: Space/Return'								 	 +chr(10)+
				  'Flag: F'											 	 +chr(10)+
				  'Exit: ESC/Q');

	randomize;

	val(paramStr(1), fw, valCode);
	if valCode>0 then exitWErr('ERROR: <width> is not an integer');
	if fw<=0 then 	  exitWErr('ERROR: <width> is zero or negative');
	val(paramStr(2), fh, valCode);
	if valCode>0 then exitWErr('ERROR: <height> is not an integer');
	if fh<=0 then 	  exitWErr('ERROR: <height> is zero or negative');
	val(paramStr(3), bperc, valCode);
	if valCode>0 then exitWErr('ERROR: <bomb-percentage> is not an integer');
	if bperc>100 then exitWErr('ERROR: <bomb-percentage> is greater than 100');
	if bperc<=0 then exitWErr('ERROR: <bomb-percentage> is zero or negative');

	tcGetAttr(0, origTerm);
	move(origTerm, term, sizeof(term));

	term.c_lflag := term.c_lflag and not (ICANON or ECHO);
	term.c_cc[VMIN] := 1;
	term.c_cc[VTIME] := 0;

	tcSetAttr(0, TCSANOW, term);
	
	esc := false;
	lost := false;
	won := false;
	first := true;
	
	bombc := (fw*fh*bperc) div 100;

	dec(fw);
	dec(fh);

	fieldSetup(field, fw, fh, bperc);

	while not esc do
	begin
		if field.cy>0 then write(chr(27), '[', field.cy, 'A');
		if field.cx>0 then write(chr(27), '[', field.cx, 'D');
		fieldPrint(field);
		if field.h+1-field.cy>0 then write(chr(27), '[', field.h+1-field.cy, 'A');
		if field.cx>0 then write(chr(27), '[', field.cx, 'C');

		if lost then break;
		if bombc=fieldClosed(field) then
		begin
			won := true;
			break
		end;

		read(buff);
		case buff of
			chr(27), 'q': esc := true;

			'w': if field.cy>0 then
				begin dec(field.cy); write(chr(27), '[1A') end;
			'a': if field.cx>0 then 
				begin dec(field.cx); write(chr(27), '[1D') end;
			's': if field.cy<field.h then
				begin inc(field.cy); write(chr(27), '[1B') end;
			'd': if field.cx<field.w then
				begin inc(field.cx); write(chr(27), '[1C') end;
			'f': begin
					if not field.open[field.cx][field.cy] then
						field.flags[field.cx][field.cy] :=
							not field.flags[field.cx][field.cy];
				end;

			chr(10), ' ': begin
					if fieldOpen(field, field.cx, field.cy, true) then
						if first then fieldMoveMineRand(field, field.cx, field.cy)
						else begin
							lost := true;
							fieldOpenMines(field)
						end;
					first := false
				end
		end
	end;

	write(chr(27), '[', field.h+1-field.cy, 'B',
		  chr(27), '[', field.cx, 'D');

	tcSetAttr(0, TCSANOW, origTerm);
	
	if lost then writeln('You lost! :(');
	if won  then writeln('You won! :)')
end.
