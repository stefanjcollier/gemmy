# Gemmy
A tool to control you local bundle config

## Features
 - Recursively check the Gemfile to see if they are used locally and are on the correct branch
 - (Incoming) Specify a local branch
 - (Incoming) Revert to using the remote code
 - (Incoming) Attempt to change the branches to help

## Usage
Go a repo with a Gemfile and then run the command like so:
```
$ gemmy
johnlewis-dressipi
   ├── cells-haml
   ├── ff_api ❌ (Needs 'rails-5-2' branch, current: 'rails-5-2-with-formatted-price')
   │   ├── rspec-ff_api
   ├── fresh_users
   ├── dressipi_health_check
   ├── dressipi_partner_api 👀
   │   ├── ff_api ❌ (Needs 'master' branch, current: 'rails-5-2-with-formatted-price')
   │   │    ├── rspec-ff_api
   ├── rspec-ff_api
```
### Notation
#### 👀 Configured correctly

```
   ├── dressipi_partner_api 👀
```

We're using `dressipi_parnter_api` locally and is configured fine

#### ❌ Branch mismatch
```
   ├── dressipi_partner_api 👀
   │   ├── ff_api ❌ (Needs 'master' branch, current: 'rails-5-2-with-formatted-price')
```
We're using `ff_api` locally and the branch required by `dressipi_partner_api` does not match your local branch

## Setup
This requires some GNU commands and then alias the script:

1. Install GNU versions of commands, they'll be accessible via g\<command\> e.g. ggrep and gcut 
```
brew install grep
brew install coreutils
```

2. Add the alias to your `.bashrc` or `.bash_profile`
```
alias gemmy='sh /path/to/gemmy/gemmy.sh'
```

