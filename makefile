SRC=main.c env.c game.c scripts/abilities/*.c scripts/projectiles/*.c scripts/enemies/*.c
INCLIDES=
INCLUDES += -Iexternal/lua
LIBS=-L. -lraylib -lm
all:
	odin build .
	./odin_one
check_leaks:
	valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes -s ./odin_one
dbg:
	gdb --args ./odin_one
