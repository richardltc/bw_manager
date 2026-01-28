package github

import (
	"encoding/json"
	"fmt"
	"net/http"
	"runtime"
	"strings"
)

// GitHubRelease matches the structure of the JSON response
type GitHubRelease struct {
	TagName string `json:"tag_name"`
}

func GetLatestDownloadUri() (tag string, url string, err error) {
	// https://github.com/richardltc/boxwallet2/releases/download/v0.0.5/boxwallet-0.0.5-linux-x64.tar.gz
	base_url := "https://github.com/richardltc/boxwallet2/releases/download/"

	latest_tag, err := getLatestReleaseTag()
	if err != nil {
		return "", "", err
	}

	filename, err := convertTagToFile(latest_tag)
	if err != nil {
		return "", "", err
	}

	// Use allocPrint to concatenate the parts into a new string
	full_url := base_url + latest_tag + "/" + filename

	return full_url, latest_tag, nil
}

func getLatestReleaseTag() (string, error) {
	url := "https://api.github.com/repos/richardltc/boxwallet2/releases/latest"

	// Create a new request to set headers
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", err
	}

	// GitHub API requires a User-Agent
	req.Header.Set("User-Agent", "go-fetch-example")

	// Execute the request
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("HTTP Error: %d", resp.StatusCode)
	}

	// Decode the JSON directly from the response body
	var release GitHubRelease
	if err := json.NewDecoder(resp.Body).Decode(&release); err != nil {
		return "", err
	}

	return release.TagName, nil
}

func convertTagToFile(tag string) (string, error) {
	// Remove the 'v' prefix from the tag (e.g., "v0.0.5" -> "0.0.5")
	version := strings.ReplaceAll(tag, "v", "")

	const prefix = "boxwallet-"
	var suffix string

	// Determine the suffix based on the OS and architecture
	switch runtime.GOOS {
	case "linux":
		switch runtime.GOARCH {
		case "amd64":
			suffix = "linux-x64.tar.gz"
		case "arm64":
			suffix = "Linux 64-bit (ARM)"
		default:
			suffix = "Linux (Other Arch)"
		}
	case "windows":
		switch runtime.GOARCH {
		case "amd64":
			suffix = "Windows 64-bit"
		default:
			suffix = "Windows (Other/32-bit)"
		}
	case "darwin": // macOS is 'darwin' in Go
		switch runtime.GOARCH {
		case "amd64":
			suffix = "macOS (Intel)"
		case "arm64":
			suffix = "macOS (Apple Silicon/M-series)"
		default:
			suffix = "macOS (Other Arch)"
		}
	default:
		suffix = "Unsupported Operating System"
	}

	// Construct the final string: boxwallet-0.0.5-linux-x64.tar.gz
	return fmt.Sprintf("%s%s-%s", prefix, version, suffix), nil
}
