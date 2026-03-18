package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/mholt/archiver/v3"
	gh "github.com/richardltc/bw_manager/github"
	rjmInternet "github.com/richardltc/bw_manager/rjminternet"
)

func dirExists(path string) bool {
	info, err := os.Stat(path)
	if err == nil {
		return info.IsDir()
	}
	if errors.Is(err, os.ErrNotExist) {
		return false
	}
	// This covers other errors (permissions, etc.)
	return false
}

func runBoxWallet(subDir string) {
	// 1. Determine the path to the Elixir executable based on OS
	var executable string
	if runtime.GOOS == "windows" {
		executable = filepath.Join(subDir, "boxwallet", "bin", "boxwallet.bat")
	} else {
		executable = filepath.Join(subDir, "boxwallet", "bin", "boxwallet")
	}

	// 2. Setup Context to ensure Elixir dies if Go is killed
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 3. Prepare the "start" command (Releases use 'start' or 'foreground')
	// 'foreground' is often better for Go to capture logs directly.
	cmd := exec.CommandContext(ctx, executable, "start")

	// 4. Pipe logs to Go's terminal
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	fmt.Printf("Starting Elixir engine on %s...\n", runtime.GOOS)

	if err := cmd.Run(); err != nil {
		fmt.Printf("Engine stopped: %v\n", err)
	}
}

func createScripts(subDir string) {
	var scriptName, childScriptContent, parentScriptContent string

	if runtime.GOOS == "windows" {
		scriptName = "run_boxwallet.bat"
		childScriptContent = "@echo off\n.\\bin\\boxwallet.bat start\npause"
		parentScriptContent = "@echo off\n.\\" + subDir + "\\bin\\boxwallet.bat start\npause"
	} else {
		scriptName = "run_boxwallet.sh"
		childScriptContent = "#!/bin/bash\n./boxwallet/bin/boxwallet start"
		parentScriptContent = "#!/bin/bash\n./" + subDir + "/boxwallet/bin/boxwallet start"
	}

	childScriptFullPath := path.Join(subDir, scriptName)
	parentScriptFullPath := path.Join(scriptName)

	// 1. Create the parent script file
	if err := os.WriteFile(parentScriptFullPath, []byte(parentScriptContent), 0755); err != nil {
		fmt.Printf("Error creating launcher: %v\n", err)
		return
	}

	// 1. Create the child script file
	if err := os.WriteFile(childScriptFullPath, []byte(childScriptContent), 0755); err != nil {
		fmt.Printf("Error creating launcher: %v\n", err)
		return
	}

	fmt.Printf("\n✅ Launcher created: %s\n", parentScriptFullPath)
	fmt.Printf("\n✅ Launcher created: %s\n", childScriptFullPath)
	fmt.Println("Please run either of these files to start the BoxWallet engine.")
}

func main() {
	green := "\x1b[32m"
	boldGreen := "\x1b[1;32m"
	reset := "\x1b[0m"
	// On Windows, only use colours if running inside a colour-capable terminal
	// (e.g. Windows Terminal sets WT_SESSION; respect NO_COLOR on any platform)
	if os.Getenv("NO_COLOR") != "" || (runtime.GOOS == "windows" && os.Getenv("WT_SESSION") == "") {
		green = ""
		boldGreen = ""
		reset = ""
	}

	// Mocking an app struct for context
	app := struct {
		name    string
		version string
	}{
		name:    "BoxWallet Manager",
		version: "0.0.4",
	}

	// Immediate log
	fmt.Printf("%s%s%s v%s%s%s starting...\n",
		green, app.name, reset,
		green, app.version, reset,
	)

	// Defer runs when the surrounding function exits
	defer fmt.Printf("\n%s%s%s finished!\n",
		green, app.name, reset,
	)

	fmt.Printf("Checking for updates...\n")

	// Call the function using the package name prefix
	latest_version, downloadUrl, filename, err := gh.GetLatestDownloadinfo()
	if err != nil {
		log.Fatalf("Failed to fetch release: %v", err)
	}

	if !dirExists(latest_version) {
		reader := bufio.NewReader(os.Stdin)
		fmt.Print("\nThe latest version of " + green + "BoxWallet" + reset + " is: " + boldGreen + latest_version + reset + "\n\nWould you like to download it? (y/n): ")
		input, _ := reader.ReadString('\n')
		fmt.Printf("Text entered: %s\n", input)
		input = strings.TrimSpace(input)
		if input != "y" {
			fmt.Println("Update cancelled.")
			return
		}

		dir := latest_version

		if err := os.MkdirAll(dir, 0755); err != nil {
			fmt.Fprintf(os.Stderr, "unable to create directory: %v", err)
		}

		dest := path.Join(dir, filename)

		// The user has chosen to download the latest version...
		if err := rjmInternet.DownloadFile(dest, downloadUrl); err != nil {
			fmt.Fprintf(os.Stderr, "unable to download file: %v - %v", downloadUrl, err)
		}

		if err := archiver.Unarchive(dest, dir); err != nil {
			fmt.Fprintf(os.Stderr, "unable to unarchive file: %v - %v", dest, err)
		}

		if err := os.RemoveAll(dest); err != nil {
			fmt.Fprintf(os.Stderr, "unable to remove file: %v - %v", dest, err)
		}

		fmt.Println("All done!")
		createScripts(latest_version)
		lastInput, _ := reader.ReadString('\n')
		fmt.Printf("%s\n", lastInput)
		lastInput = strings.TrimSpace(lastInput)

		// fmt.Println("\n./" + dir + "/boxwallet/bin/boxwallet start")
	} else {
		// The latest version has already been downloaded, as the directory exists
		fmt.Println("You already have the latest version of " + green + "BoxWallet" + reset)
		createScripts(latest_version)
		reader := bufio.NewReader(os.Stdin)
		lastInput, _ := reader.ReadString('\n')
		fmt.Printf("%s\n", lastInput)
		lastInput = strings.TrimSpace(lastInput)
	}

	// fmt.Printf("Latest release found: %s%s%s\n", green, downloadUrl, reset)
}
