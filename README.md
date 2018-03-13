gitbucket2slack_hook
====


## Usage

    bundle install --path vendor/bundle
    mkdir log
    mkdir -p tmp/puma

###### Create a new slack bot

Create a [new bot](https://my.slack.com/services/new/bot), and note its API token.

###### Set environment variable.

    export GB2S_CONFIG_PATH="/path/to/settings.yml"

###### Edit settings.yml

    ex)
    slack_api_token: xxxx-00000-xxxxxx (bot api token)
    token2slack:
      'TOKEN1': 'https://hooks.slack.com/services/aa/bb/cc'
      'TOKEN2': 'https://hooks.slack.com/services/xx/yy/zz'



###### Launch puma server.

    bundle exec puma -e production -p 8000 -C config/puma.rb

###### Set gitbucket service hook.

- Payload URL: https&#58;//puma-server/gitbucket2slack_hook/TOKEN1
- Content type: application/json

###### Add gitbucket comment.

 ex) @hoge test comment
