# Include trycatch.sh as a library
source ~/trycatch.sh

## Aliases
alias home='cd ~/.'
alias ll="ls -la"
alias reload='source ~/.bashrc'
alias findpid='lsof -i :$1'

#GIT
alias gsts='git status'
alias gp='git pull'
alias gc='git commit'
alias gca='git commit --amend --no-edit'
alias gra='git restore .'
alias gmod='git fetch origin && git merge origin develop'
alias gmom='git fetch origin && git merge origin/master'
alias gco='git checkout $1'
alias gmvb='git branch -m $1 $2'
alias grmb='git branch -D $1'
alias grmrb='git push origin --delete $1'
alias grc='git rm -r --cached $1'
alias gdco='git push origin +HEAD^:$1'

#NPM
alias update-angular-minor='npx npm-check-updates --upgrade --target "minor" --filter "/@angular.*/"'

#Python
alias python='/usr/bin/python3'
alias p38='/opt/homebrew/bin/python3.8'
alias pyenv='python -m venv $1'
alias pyinstall='pip3 install -r ./requirements.txt'

##trap 'catch $? $LINENO' ERR
##catch() {
##  echo "Error $1 occurred on $2"
##}

##################### functions ############################
export ERR_BAD=100
export ERR_WORSE=101
export ERR_CRITICAL=102

add_alias () {
  # File to modify
  BASHRC_FILE="$HOME/.bashrc"

  # Prompt the user to select a header type
  echo "1) Git"
  echo "2) Go"
  echo "3) Core"
  read -p "type: " HEADER_CHOICE

  # Set the header based on user selection
  case $HEADER_CHOICE in
      1) HEADER="## Git" ;;
      2) HEADER="## Go" ;;
      3) HEADER="## Core" ;;
      *) echo "Invalid option"; exit 1 ;;
  esac

  # Prompt the user to input the alias
  read -p "Enter the alias (e.g., alias foo='bar'): " NEW_ALIAS

  # Add the new alias after the selected header
  # This will insert the alias on the line right after the header section
  sed -i "/^$HEADER$/a\\
$NEW_ALIAS" "$BASHRC_FILE"

  # Feedback to the user
  echo "Alias added under $HEADER."

  # Optional: reload .bashrc to apply the changes
  # Uncomment the line below if you want to reload bashrc immediately.
  source "$BASHRC_FILE"  
}

get_current_branch () {
  try
  (
      local branch=$(git branch --show-current) 2> /dev/null || throw $ERR_BAD
      echo "$branch"
  )
  catch || {
      case $exception_code in
          $ERR_BAD)
              echo "You are not in a git repository"
          ;;
          *)
              echo "Unknown error: $exit_code"
              throw $exit_code    # re-throw an unhandled exception
          ;;
      esac
  }
}

get_main_or_master () {
  try
  (
    local branch=$(git branch -l master main) 2> /dev/null || throw $ERR_BAD
    echo "$branch" | xargs
  )
  catch || {
    case $exception_code in
      $ERR_BAD)
        echo "You are not in a git repository"
      ;;
      *)
        echo "Unknown error: $exit_code"
        throw $exit_code
      ;;
    esac
  }
}

gcom () {
  local b=$(get_main_or_master)

  try
  (
    git checkout "$b" 2> /dev/null || throw $ERR_BAD
  )
  catch || {
    case $exception_code in
      $ERR_BAD)
        echo "Error checking out $b"
      ;;
      *)
        echo "Unknown error: $exit_code"
        throw $exit_code
      ;;
    esac
  }
}

gdlb () {
  try
  (
    git fetch -p 2> /dev/null || throw $ERR_BAD

    # for branch in $(git for-each-ref --format "%(refname) %(upstream:track)" refs/heads | awk '$2 == "[gone]" {sub("refs/heads/", "", $1); print $1}'); do git branch -D $branch; done || throw $ERR_WORSE
    local branches=$(git for-each-ref --format "%(color:yellow)%(refname)%(color:reset) %(color:red)%(upstream:track)%(color:reset)" refs/heads | awk '$2 == "[gone]" {sub("refs/heads/", "", $1); print $1}') || throw $ERR_WORSE
    if [ -z "$branches" ]; then
      echo 'No stale branches.'
      return
    else
      echo "found the following stale branches to delete:\n$branches"
      while IFS= read -r branch; do
        echo "deleting $branch"
        git branch -D $branch || throw $ERR_CRITICAL
      done <<< "$branches"
    fi

    echo "Done."
  )
  catch || {
    case $exception_code in
      $ERR_BAD)
        echo "You are not in a git repository"
      ;;
      $ERR_WORSE)
        echo "Something went wrong getting stale branches"
      ;;
      $ERR_CRITICAL)
        echo "Failed deleting branches"
      ;;
      *)
        echo "Unknown error: $exit_code"
        throw $exit_code
      ;;
    esac
  }
}

gsu () {
  local b=$(get_current_branch)

  try
  (
    git branch -u origin/"$b" 2> /dev/null || throw $ERR_BAD
  )
  catch || {
    case $exception_code in
      $ERR_BAD)
        echo "Branch $b has not been published."
        echo "Do you wish to publish it?"
        select yn in "Yes" "No"; do
          case $yn in
            Yes ) publish; break;;
            No ) exit;;
          esac
        done
      ;;
      *)
        echo "Unknown error: $exit_code"
        throw $exit_code
      ;;
    esac
  }
}

nb () {
  local new_branch=$1
  
  if [ -z "$new_branch" ]; then
    echo 'Specify a branch name.'
    return
  fi

  try
  (
    git checkout -b $1 && publish && gsu || throw $ERR_BAD
  )
  catch || {
    case $exception_code in
      $ERR_BAD)
        echo "Something fucked up, check the branch was created and published."
      ;;
      *)
        echo "Unknown error: $exit_code"
        throw $exit_code    # re-throw an unhandled exception
      ;;
    esac 
  }
}

publish () {
  local b=$(get_current_branch)

  git push -u origin $b
  echo "Published $b"
}

gcwip () {
  local b=$(get_current_branch)

  git commit -m "$b: WIP"
}

gcmsg () {
  local message=$1
  local b=$(get_current_branch)

  git commit -m "$b: $message"
}

gmvrb () {
  local new=$1
  local old=$(get_current_branch)

  # Rename the local branch to the new name
  git branch -m $old $new

  # Delete the old branch on remote - where origin is, for example, origin
  # git push origin --delete $old

  # Or shorter way to delete remote branch [:]
  git push origin :$old

  # Prevent git from using the old name when pushing in the next step.
  # Otherwise, git will use the old upstream name instead of $new.
  git branch --unset-upstream $new

  # Push the new branch to remote
  git push origin $new

  # Reset the upstream branch for the new_name local branch
  git push origin -u $new
}

# Docker
docker_kill_like() {
  # Check if an argument is provided
  if [ -z "$1" ]; then
    echo "Please provide an image name substring."
    return 1
  fi

  # Store the argument in a variable
  IMAGE_NAME_SUBSTRING=$1

  # Get the container ID(s) of matching image name(s) using grep for loose matching
  CONTAINER_INFOS=$(docker ps --format "{{.ID}} {{.Image}}" | grep "$IMAGE_NAME_SUBSTRING")

  # Check if any container infos were found
  if [ -z "$CONTAINER_INFOS" ]; then
    echo "No running containers found with image name containing '$IMAGE_NAME_SUBSTRING'."
    return 1
  fi

  # Prompt for confirmation and kill the matching containers
  echo "Found containers with image name containing '$IMAGE_NAME_SUBSTRING':"
  for CONTAINER_INFO in $CONTAINER_INFOS; do
    CONTAINER_ID=$(echo $CONTAINER_INFO | awk '{print $1}')
    IMAGE_NAME=$(echo $CONTAINER_INFO | awk '{print $2}')
    
    read "response?Do you want to kill container ID: $CONTAINER_ID with image: $IMAGE_NAME? (y/n) "
    if [[ "$response" == "y" || "$response" == "Y" ]]; then
      echo "Killing container ID: $CONTAINER_ID"
      docker kill "$CONTAINER_ID"
    else
      echo "Skipping container ID: $CONTAINER_ID"
    fi
  done
}
