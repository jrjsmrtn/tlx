---- MODULE ProducerConsumer ----
EXTENDS Integers, FiniteSets

CONSTANTS max_buf

VARIABLES buf_size, produced, consumed

vars == << buf_size, produced, consumed >>

Init ==
    /\ buf_size = 0
    /\ produced = 0
    /\ consumed = 0

produce ==
    /\ buf_size < max_buf
    /\ buf_size' = buf_size + 1
    /\ produced' = produced + 1
    /\ UNCHANGED << consumed >>

consume ==
    /\ buf_size > 0
    /\ buf_size' = buf_size - 1
    /\ consumed' = consumed + 1
    /\ UNCHANGED << produced >>

Next ==
    \/ produce
    \/ consume

Fairness ==
    /\ WF_vars(produce)
    /\ WF_vars(consume)

Spec == Init /\ [][Next]_vars /\ Fairness

buffer_bounded == (buf_size >= 0 /\ buf_size <= max_buf)
consumption_valid == consumed <= produced

eventually_consumed == [](<>(buf_size = 0))

====
