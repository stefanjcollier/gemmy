# Gemmy
A tool to control you local bundle config

## Features
 - Recursively check the Gemfile to see if they are used locally and are on the correct branch
 - Specify a local branch
 - Revert to using the remote code
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
Specify a gem to use locally
```
$ gemmy local ff_api
Using ff_api at: /Users/stefancollier/Source/ff_api
```

Stop using a local gem
```
$ gemmy remote ff_api
No longer using ff_api locally
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
### Prerequisites
The installer script requires `brew`

### Install!
Run the following command
```
mkdir -p ~/scripts
cd ~/scripts
git clone git@github.com:stefanjohncollier/gemmy.git
cd gemmy
./install.sh
source ~/.bash_profile
```

