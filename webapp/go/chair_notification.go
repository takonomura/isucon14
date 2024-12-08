package main

import "sync"

var charNotificationSignals = new(sync.Map)

func registerCharNotificationSignalHandler(chairID string, ch chan<- struct{}) {
	charNotificationSignals.Store(chairID, ch)
}

func unregisterCharNotificationSignalHandler(chairID string, ch chan<- struct{}) {
	charNotificationSignals.CompareAndDelete(chairID, ch)
}

func signalCharNotification(charID string) {
	v, ok := charNotificationSignals.Load(charID)
	if !ok {
		return
	}
	ch := v.(chan<- struct{})
	select {
	case ch <- struct{}{}:
	default:
	}
}
