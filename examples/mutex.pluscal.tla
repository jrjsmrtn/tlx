---- MODULE Mutex ----
EXTENDS Integers, FiniteSets

(* --algorithm Mutex
variables
    pc1 = "idle",
    pc2 = "idle",
    turn = 1,
    flag1 = FALSE,
    flag2 = FALSE;

{
    p1_try:
        await pc1 = "idle";
        flag1 := TRUE;
        turn := 2;
        pc1 := "waiting";
    p1_enter:
        await (pc1 = "waiting" /\ (flag2 = FALSE \/ turn = 1));
        pc1 := "cs";
    p1_exit:
        await pc1 = "cs";
        flag1 := FALSE;
        pc1 := "idle";
    p2_try:
        await pc2 = "idle";
        flag2 := TRUE;
        turn := 1;
        pc2 := "waiting";
    p2_enter:
        await (pc2 = "waiting" /\ (flag1 = FALSE \/ turn = 2));
        pc2 := "cs";
    p2_exit:
        await pc2 = "cs";
        flag2 := FALSE;
        pc2 := "idle";
}
*)\* end algorithm

mutual_exclusion == ~((pc1 = "cs" /\ pc2 = "cs"))

====
