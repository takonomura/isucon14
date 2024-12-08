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

var appNotificationSignals = new(sync.Map)

func registerAppNotificationSignalHandler(userID string, ch chan<- struct{}) {
	appNotificationSignals.Store(userID, ch)
}

func unregisterAppNotificationSignalHandler(userID string, ch chan<- struct{}) {
	appNotificationSignals.CompareAndDelete(userID, ch)
}

func signalAppNotification(userID string) {
	v, ok := appNotificationSignals.Load(userID)
	if !ok {
		return
	}
	ch := v.(chan<- struct{})
	select {
	case ch <- struct{}{}:
	default:
	}
}
