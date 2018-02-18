**\*\*\*\*\* UNDER DEVELOPMENT \*\*\*\*\***

gitbucket2slack_hook
====


## Usage

    bundle install --path vendor/bundle
    mkdir log
    mkdir -p tmp/puma

###### Create a new slack bot

Create a [new bot](https://my.slack.com/services/new/bot), and note its API token.

###### Set environment variables.

    export SLACK_API_TOKEN="xxxx-0000-xxxxxx" (bot API token)
    export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/xxxx/xxxxxx"
    export ACCESS_URL_TOKEN=xxxxyyyyzzzz

###### Launch puma server.

    bundle exec puma -e production -p 8000 -C config/puma.rb

###### Set gitbucket service hook.

- Payload URL: https&#58;//puma-server/gitbucket2slack_hook/ACCESS_URL_TOKEN
- Content type: application/json

###### Add gitbucket comment.

 ex) @hoge test comment
