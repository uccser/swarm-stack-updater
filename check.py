#! /user/bin/python

import argparse
import subprocess

import requests
import sys


def update_swarm():
    sys.stdout.write("Updating Docker Stack")
    subprocess.run(["docker", "stack", "deploy", "-c", "docker-compose.prod.yml", "test"])


def download_files(repo, develop):
    if develop:
        file_url = "https://raw.githubusercontent.com/uccser/{}/develop/docker-compose.prod.yml"
    else:
        file_url = "https://raw.githubusercontent.com/uccser/{}/master/docker-compose.prod.yml"

    r = requests.get(file_url.format(repo))
    if not r.ok:
        sys.stdout.write("Error ({}): {}".format(r.status_code, r.reason))
        sys.stdout.write("Unable to reach url ({}). Exiting... \n".format(file_url))
        exit(1)

    f = open("docker-compose.prod.yml", 'w')
    f.write(r.text)
    f.close()


def main():
    # Ensure that all arguments required are present
    arg_parser = argparse.ArgumentParser(description="Monitoring script For UCCSER DockerSwarm websites")
    arg_parser.add_argument('-d', '--dev', action='store_true', help="Run this tool for dev environment")
    arg_parser.add_argument('url', help="Url for the website you are checking.")
    arg_parser.add_argument('repository', help="Repository of website source code.")
    args = arg_parser.parse_args()

    status_url = "{}/status"
    status_url = status_url.format(args.url)
    github_repository = args.repository

    # Check website status and retrieve required information
    r = requests.get(status_url)
    if not r.ok:
        # Health-checks should keep an eye on this. May want to stop cron job?
        sys.stdout.write("Error ({}): {}".format(r.status_code, r.reason))
        sys.stdout.write("Unable to reach url ({}). Exiting... \n".format(status_url))
        exit(1)

    r_data = r.json()
    version_number = r_data["VERSION_NUMBER"]
    git_sha = r_data["GIT_SHA"]

    repo_url = "https://api.github.com/repos/uccser/{}".format(github_repository)

    if args.dev:
        repo_request = requests.get(repo_url + "/commits/develop")
        if not repo_request.ok:
            # Can't find Github repository
            sys.stdout.write("Error ({}): {}".format(repo_request.status_code, repo_request.reason))
            sys.stdout.write("Unable to reach repository ({}). Exiting... \n".format(github_repository))
            exit(1)

        repo_data = repo_request.json()
        if git_sha != repo_data["sha"][:len(git_sha)]:
            print("Update")
            download_files(github_repository, args.dev)
            update_swarm()
        else:
            print("Don't Update")

    else:
        repo_request = requests.get(repo_url + "/releases/latest")
        if not repo_request.ok:
            # Can't find Github repository
            sys.stdout.write("Error ({}): {}".format(repo_request.status_code, repo_request.reason))
            sys.stdout.write("Unable to reach repository ({}). Exiting... \n".format(github_repository))
            exit(1)

        repo_data = repo_request.json()
        version_tag = repo_data["name"]

        if version_tag != version_number:
            # Update
            pass
        else:
            # Dont Update
            print("No update required")


main()
