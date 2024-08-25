package main

import (
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"regexp"
	"time"

	"github.com/jessevdk/go-flags"
	// "github.com/sweetbbak/toru/pkg/libtorrent"
)

var opts struct {
	Verbose     []bool `short:"v" long:"verbose" description:"Verbose output"`
	DisableIPV6 bool   `short:"4" long:"ipv4"    description:"use IPV4 instead of IPV6"`
	RemoveDir   bool   `short:"c" long:"cleanup" description:"delete the data directory storing downloaded torrents"`
	Info        bool   `          long:"info"    description:"get info from magnet"`
	Port        string `short:"p" long:"port"    description:"set the port that torrents are streamed over"`
	Magnet      string `short:"t" long:"torrent" description:"path to torrent, URL or magnet link"`
	Socket      string `short:"s" long:"socket"  description:"path to mpv socket"`
	DownloadDir string `short:"o" long:"output"  description:"set the parent output directory to download into"`
}

type Output struct {
	Name string
	Link string
	Pid  int
}

func cleanString(s string) string {
	re := regexp.MustCompile(`[^a-zA-Z0-9 \!\?\,\.\(\)]+`)
	t := re.ReplaceAllLiteralString(s, "")
	return t
}

func StreamTorrent(cl *Client, torfile string) error {
	t, err := cl.AddTorrent(torfile)
	if err != nil {
		return err
	}

	link := cl.ServeTorrent(t)
	fmt.Println(link)

	payload := fmt.Sprintf(`{ "command": ["loadfile", "%s"] }`, link)
	err = ConnectMpv(opts.Socket, payload)
	if err != nil {
		return err
	}

	HandleExit()

	// block
	for {
		time.Sleep(time.Second * 1)
	}
}

func HandleExit() {
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func() {
		<-c
		fmt.Printf("Exiting...\n")
		os.Exit(0)
	}()
}

var retry int

func getInfo() error {
	time.Sleep(time.Millisecond * 50)
	if retry >= 3 {
		return fmt.Errorf("unable to reach server")
	}

	r, err := http.Get(fmt.Sprintf("http://localhost:%s/info", opts.Port))
	if err != nil {
		retry++
		getInfo()
	}

	defer r.Body.Close()
	_, err = io.Copy(os.Stdout, r.Body)
	if err != nil {
		return err
	}
	return nil
}

func GetFreePort() (int, error) {
	addr, err := net.ResolveTCPAddr("tcp", "localhost:0")
	if err != nil {
		return 0, err
	}

	l, err := net.ListenTCP("tcp", addr)
	if err != nil {
		return 0, err
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port, nil
}

func init() {
	p, err := GetFreePort()
	if err != nil {
		p = 8080
	}
	opts.Port = fmt.Sprintf("%d", p)
}

func main() {
	_, err := flags.Parse(&opts)
	if flags.WroteHelp(err) {
		os.Exit(1)
	}
	if err != nil {
		log.Fatal(err)
	}

	if opts.Info {
		if err := getInfo(); err != nil {
			log.Fatal(err)
		}
		os.Exit(0)
	}

	cl := NewClient("mpv-torrent", opts.Port)
	if opts.DownloadDir != "" {
		cl.DataDir = opts.DownloadDir
	}

	cl.DisableIPV6 = opts.DisableIPV6

	if err := cl.Init(); err != nil {
		log.Fatal(err)
	}

	err = StreamTorrent(cl, opts.Magnet)
	if err != nil {
		log.Fatal(err)
	}
}
