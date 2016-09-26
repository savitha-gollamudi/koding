package stackplan

import (
	"fmt"
	"net/url"
	"time"

	"koding/db/mongodb/modelhelper"
	"koding/kites/kloud/machinestate"
	"koding/kites/kloud/stack"
	"koding/kites/kloud/utils/object"

	"golang.org/x/net/context"
	"gopkg.in/mgo.v2/bson"
)

func (bm *BaseMachine) HandleStart(ctx context.Context) error {
	origState := bm.State()
	currentState := origState

	realState, meta, err := bm.machine.Info(ctx)
	if err != nil {
		return err
	}

	defer func() {
		if err != nil && origState != currentState {
			modelhelper.ChangeMachineState(bm.ObjectId, "Machine is marked as "+origState.String(), origState)
		}
	}()

	if !realState.In(machinestate.Running, machinestate.Starting) {
		currentState = machinestate.Starting

		bm.PushEvent("Starting machine", 25, currentState)

		err = modelhelper.ChangeMachineState(bm.ObjectId, "Machine is starting", currentState)
		if err != nil {
			return err
		}

		meta, err = bm.machine.Start(ctx)
		if err != nil {
			return stack.NewEventerError(err)
		}
	}

	bm.PushEvent("Checking remote machine", 75, currentState)

	dialState, err := bm.WaitKlientReady(0)
	if err != nil {
		return stack.NewEventerError(err)
	}

	if err := bm.updateMachine(dialState, meta, machinestate.Running); err != nil {
		return fmt.Errorf("failed to update machine: ", err)
	}

	return nil
}

func (bm *BaseMachine) HandleStop(ctx context.Context) error {
	origState := bm.State()
	currentState := origState

	realState, meta, err := bm.machine.Info(ctx)
	if err != nil {
		return err
	}

	defer func() {
		if err != nil && origState != currentState {
			modelhelper.ChangeMachineState(bm.ObjectId, "Machine is marked as "+origState.String(), origState)
		}
	}()

	if !realState.In(machinestate.Running, machinestate.Starting) {
		currentState = machinestate.Stopping

		bm.PushEvent("Stopping machine", 25, currentState)

		err = modelhelper.ChangeMachineState(bm.ObjectId, "Machine is stopping", currentState)
		if err != nil {
			return err
		}

		meta, err = bm.machine.Stop(ctx)
		if err != nil {
			return stack.NewEventerError(err)
		}
	}

	if err := bm.updateMachine(nil, meta, machinestate.Stopped); err != nil {
		return fmt.Errorf("failed to update machine: ", err)
	}

	return nil
}

func (bm *BaseMachine) HandleInfo(ctx context.Context) (*stack.InfoResponse, error) {
	var state *DialState

	origState := bm.State()

	currentState, meta, err := bm.machine.Info(ctx)
	if err != nil {
		return nil, err
	}

	defer func() {
		if meta != nil || state != nil {
			bm.updateMachine(state, meta, currentState)
		} else if currentState != origState {
			modelhelper.ChangeMachineState(bm.ObjectId, "Machine is marked as "+currentState.String(), currentState)
		}
	}()

	if currentState.InProgress() {
		return &stack.InfoResponse{
			State: currentState,
		}, nil
	}

	if origState == currentState && currentState != machinestate.Running {
		return &stack.InfoResponse{
			State: origState,
		}, nil
	}

	if alwaysOn, ok := bm.Meta["alwaysOn"].(bool); ok && alwaysOn && currentState == machinestate.Running {
		// We do not test klient connection when machine is always-on.
		// Most likely we assume that kloud/queue is going to start/restart
		// the vm if klient connectivity fails.
		return &stack.InfoResponse{
			State: currentState,
		}, nil
	}

	if state, err = bm.WaitKlientReady(10 * time.Second); err == nil {
		currentState = machinestate.Running
	} else {
		bm.Log.Debug("klient connection test failed %q: %s", bm.Label, err)
	}

	return &stack.InfoResponse{
		State: currentState,
	}, nil
}

func (bm *BaseMachine) updateMachine(state *DialState, meta interface{}, dbState machinestate.State) error {
	var ipAddress string

	if state != nil {
		ipAddress = state.KiteURL
		if u, err := url.Parse(state.KiteURL); err == nil {
			ipAddress = u.Host
		}
	}

	obj := object.MetaBuilder.Build(meta)

	obj["ipAddress"] = ipAddress
	obj["status.modifiedAt"] = time.Now().UTC()
	obj["status.state"] = dbState.String()
	obj["status.reason"] = "Machine is " + dbState.String()

	bm.Log.Debug("update object for %q: %+v", bm.Label, obj)

	return modelhelper.UpdateMachine(bm.ObjectId, bson.M{"$set": obj})
}
