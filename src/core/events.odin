package core

import "../shared"
import "core:sync"

Window_Resized :: struct {
	width, height: i32,
}

Event :: union {
	Window_Resized,
	shared.Mouse_Input,
	shared.Key_Input,
}

CAPACITY :: 256

Event_Channel :: struct {
	buffer: [CAPACITY]Event,
	head:   int,
	tail:   int,
	count:  int,
	mutex:  sync.Mutex,
}

publish :: proc(ch: ^Event_Channel, ev: Event) -> bool {
	sync.lock(&ch.mutex)
	defer sync.unlock(&ch.mutex)

	if ch.count >= CAPACITY {
		return false
	}

	ch.buffer[ch.head] = ev
	ch.head = (ch.head + 1) % CAPACITY
	ch.count += 1
	return true
}

poll :: proc(ch: ^Event_Channel) -> (Event, bool) {
	sync.lock(&ch.mutex)
	defer sync.unlock(&ch.mutex)

	if ch.count == 0 {
		return nil, false
	}

	ev := ch.buffer[ch.tail]
	ch.tail = (ch.tail + 1) % CAPACITY
	ch.count -= 1
	return ev, true
}

// Helper to flush or process all queued events in a frame loop
clear :: proc(ch: ^Event_Channel) {
	sync.lock(&ch.mutex)
	defer sync.unlock(&ch.mutex)
	ch.head = 0
	ch.tail = 0
	ch.count = 0
}
