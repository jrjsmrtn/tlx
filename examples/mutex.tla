---- MODULE Mutex ----
EXTENDS Integers, FiniteSets

VARIABLES pc1, pc2, turn, flag1, flag2

vars == << pc1, pc2, turn, flag1, flag2 >>

Init ==
    /\ pc1 = idle
    /\ pc2 = idle
    /\ turn = 1
    /\ flag1 = FALSE
    /\ flag2 = FALSE

p1_try ==
    /\ pc1 = idle
    /\ flag1' = TRUE
    /\ turn' = 2
    /\ pc1' = waiting
    /\ UNCHANGED << pc2, flag2 >>

p1_enter ==
    /\ (pc1 = waiting /\ (flag2 = FALSE \/ turn = 1))
    /\ pc1' = cs
    /\ UNCHANGED << pc2, turn, flag1, flag2 >>

p1_exit ==
    /\ pc1 = cs
    /\ flag1' = FALSE
    /\ pc1' = idle
    /\ UNCHANGED << pc2, turn, flag2 >>

p2_try ==
    /\ pc2 = idle
    /\ flag2' = TRUE
    /\ turn' = 1
    /\ pc2' = waiting
    /\ UNCHANGED << pc1, flag1 >>

p2_enter ==
    /\ (pc2 = waiting /\ (flag1 = FALSE \/ turn = 2))
    /\ pc2' = cs
    /\ UNCHANGED << pc1, turn, flag1, flag2 >>

p2_exit ==
    /\ pc2 = cs
    /\ flag2' = FALSE
    /\ pc2' = idle
    /\ UNCHANGED << pc1, turn, flag1 >>

Next ==
    \/ p1_try
    \/ p1_enter
    \/ p1_exit
    \/ p2_try
    \/ p2_enter
    \/ p2_exit

Fairness ==
    /\ WF_vars(p1_enter)
    /\ WF_vars(p2_enter)

Spec == Init /\ [][Next]_vars /\ Fairness

mutual_exclusion == ~((pc1 = cs /\ pc2 = cs))

p1_eventually_enters == [](<>(pc1 = cs))

====
