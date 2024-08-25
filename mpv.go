package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net"
	// "github.com/gen2brain/go-mpv"
)

func DaemonSocket(sock, link string) error {
	var x net.UnixAddr
	x.Name = sock
	x.Net = "unix"
	socket, err := net.ListenUnix("unix", &x)
	if err != nil {
		return fmt.Errorf("Error listening:", err.Error())
	}
	defer socket.Close()

	for {

		conn, err := socket.Accept()
		if err != nil {
			return err
		}
		defer conn.Close()

		buf := make([]byte, 2048)
		var msg string
		for {
			n, err := conn.Read(buf)
			if err == io.EOF {
				break
			}
			if err != nil {
				fmt.Println("Error reading:", err.Error())
				break
			}

			msg = string(buf[0:n])
			fmt.Println("Received message:", msg)

		}

		if msg != "" {
			o := &Output{Link: link}
			b, _ := json.Marshal(&o)
			conn.Write(b)
		}
	}
	return nil
}

func ConnectMpv(sock, msg string) error {
	var x net.UnixAddr
	x.Name = sock
	x.Net = "unix"
	socket, err := net.ListenUnix("unix", &x)
	if err != nil {
		return fmt.Errorf("Error listening:", err.Error())
	}
	defer socket.Close()

	conn, err := socket.Accept()
	if err != nil {
		return err
	}
	defer conn.Close()

	conn.Write([]byte(msg))
	return nil
}
