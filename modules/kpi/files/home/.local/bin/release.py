#!/usr/bin/env python
import argparse
import sys
import json
from os.path import exists
from subprocess import run, PIPE


parser = argparse.ArgumentParser(description='release tool')
parser.add_argument('-c', '--commit', action='store_true')
parser.add_argument('branch')
args = parser.parse_args()


def cmd(command):
    out = (run(command, stdout=PIPE, check=True, shell=True)
           .stdout.decode('utf8').split('\n'))
    return [x for x in out if x]


def git_file(branch, name):
    return '\n'.join(cmd('git show {}:{}'.format(branch, name)))


def parse_version(branch):
    return json.loads(git_file(branch, 'package.json'))['version']


def prompt(question):
    if input('{} Y/n:\n'.format(question)).lower() == 'y':
        return True


def commit_cmd(command):
    if args.commit:
        cmd(command)
    else:
        print('Skip command: {}'.format(command))


def get_current_branch():
    return cmd('git rev-parse --abbrev-ref HEAD')[0]


def get_tag():
    return parse_version(args.branch)


def checkout(branch):
    cmd('git checkout {}'.format(branch))


def tag_exists(tag):
    tags = cmd('git tag -l')
    return tag in tags


def merge(branch):
    commit_cmd('git merge --ff-only {}'.format(branch))


def push():
    commit_cmd('git push')


def tag_create(tag):
    commit_cmd('git tag -am {0} {0}'.format(tag))


def tags_push():
    commit_cmd('git push --tags')


def main():
    tag = get_tag()

    if tag_exists(tag):
        print('Tag {!r} is already exists'.format(tag))
        exit(1)

    merge(args.branch)
    push()
    tag_create(tag)
    tags_push()


if __name__ == '__main__':
    print('Args: {}'.format(args))
    curr_branch = get_current_branch()
    if curr_branch == 'HEAD':
        print('Cannot operate in detached branch')
        exit(1)
    elif curr_branch not in ('master', 'staging'):
        if not prompt('Do you want go with {!r}'.format(curr_branch)):
            exit(0)

    if not exists('package.json'):
        print('We support only node libraries releases for now')
        exit(1)

    main()
