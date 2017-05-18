#!/usr/bin/env python
import sys
import json
from subprocess import run, PIPE


def cmd(command):
    out = (run(command, stdout=PIPE, check=True, shell=True)
           .stdout.decode('utf8').split('\n'))
    return [x for x in out if x]


def get_branch():
    return sys.argv[1]


def get_tag():
    with open('package.json') as f:
        return json.load(f)['version']


def checkout(branch):
    cmd('git checkout {}'.format(branch))


def tag_exists(tag):
    tags = cmd('git tag -l')
    return tag in tags


def merge(branch):
    cmd('git merge --ff-only {}'.format(branch))


def push():
    cmd('git push')


def tag_create(tag):
    cmd('git tag -am {0} {0}'.format(tag))


def tags_push():
    cmd('git push --tags')


def main():
    branch = get_branch()
    checkout(branch)
    tag = get_tag()

    if tag_exists(tag):
        exit(1)

    checkout('staging')
    merge(branch)
    push()
    tag_create(tag)
    tags_push()


if __name__ == '__main__':
    main()
