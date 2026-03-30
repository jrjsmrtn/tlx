---- MODULE ProducerConsumer ----
EXTENDS Integers, FiniteSets

CONSTANTS max_buf

(* --algorithm ProducerConsumer
variables
    buf_size = 0,
    produced = 0,
    consumed = 0;

{
    produce:
        await buf_size < max_buf;
        buf_size := buf_size + 1;
        produced := produced + 1;
    consume:
        await buf_size > 0;
        buf_size := buf_size - 1;
        consumed := consumed + 1;
}
*)\* end algorithm

buffer_bounded == (buf_size >= 0 /\ buf_size <= max_buf)
consumption_valid == consumed <= produced

====
