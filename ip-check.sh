#!/bin/bash
clear

# List of sites to check
SITES=(
  "https://check-host.net/"
  "https://www.freepik.com/"
  "https://www.soccer24.com/"
  "https://gemini.google.com/"
  "https://developers.google.com/"
  "https://www.lcw.com/"
  "https://ipinfo.io/"
  "https://cloud.unity.com/home/login"
  "https://www.chaos.com/"
  "https://account.ninjatrader.com/register"
  "https://www.overleaf.com/"
  "https://www.pngwing.com/"
)

# Function to check site status by analyzing status code and checking for block content
check_site() {
  local site="$1"
  local temp_file
  temp_file=$(mktemp)

  # Fetch response status code and body content
  status_code=$(curl -s -o "$temp_file" -w "%{http_code}" --max-time 15 --retry 3 "$site")
  content=$(< "$temp_file")

  # Check if curl failed
  if [[ $? -ne 0 ]]; then
    echo -e "Error: \033[1;31mFailed to fetch\033[0m $site"
    rm -f "$temp_file"
    return 1
  fi

  # Check for block status codes
  if [[ "$status_code" -eq 403 ]]; then
    echo -e "Site: \033[1;31m$site\033[0m - Status: \033[1;31mBlocked (HTTP $status_code)\033[0m"
  elif [[ "$status_code" -eq 429 ]]; then
    echo -e "Site: \033[1;31m$site\033[0m - Status: \033[1;31mBlocked (HTTP $status_code)\033[0m"
  else
    # Check for common block keywords in the content
    if echo "$content" | grep -qi "403 Forbidden"; then
      echo -e "Site: \033[1;31m$site\033[0m - Status: \033[1;31mBlocked 403 Forbidden Detected\033[0m"
    elif echo "$content" | grep -qi "Access Denied"; then
      echo -e "Site: \033[1;31m$site\033[0m - Status: \033[1;31mBlocked Access Denied Detected\033[0m"
    elif echo "$content" | grep -qi "Permission Denied"; then
      echo -e "Site: \033[1;31m$site\033[0m - Status: \033[1;31mBlocked Permission Denied Detected\033[0m"
    elif echo "$content" | grep -qi "Captcha"; then
      echo -e "Site: \033[1;33m$site\033[0m - Status: \033[1;33mCaptcha Detected\033[0m"
    elif echo "$content" | grep -qi "you have been blocked"; then
      echo -e "Site: \033[1;31m$site\033[0m - Status: \033[1;31mBlocked Blocked Message Detected\033[0m"
    elif [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
      if [[ -z "$content" ]]; then
        echo -e "Site: \033[1;33m$site\033[0m - Status: \033[1;33mLoaded Partially (Captcha or Blocker Detected)\033[0m"
      else
        echo -e "Site: \033[1;32m$site\033[0m - Status: \033[1;32mAccessible HTTP $status_code\033[0m"
      fi
    else
      echo -e "Site: \033[1;33m$site\033[0m - Status: \033[1;33mOther (HTTP $status_code)\033[0m"
    fi
  fi

  # Clean up temporary file
  rm -f "$temp_file"
}

# Loop through each site and check
for site in "${SITES[@]}"; do
  check_site "$site"
done
