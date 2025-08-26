# Github runner ansible deployment

This ansible deployment allows you to deploy self-hosted github runner used by the [meshtastic firmware project](https://github.com/meshtastic/firmware).
Those runners are building firmware for meshtastic devices.

## What do I need to use it ?

### On your local machine

To be able to use this playbook you need have [Ansible installed](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) on your local machine.
A github token provided by the meshtastic crew is also required.

### On your runner's remote machine

Currently only a debian or fedora based system is supported.
You need to have a SSH remote access user able to escalate using sudo.
This is required as this playbook will install [required tools](./roles/basic-os/tasks/basic-os.yml#L1-L22) and configure your system to be able to run podman containers (the actual github runner containers).

## What does it do ?

* create an unprivileged `github` user: [here](./roles/basic-os/tasks/basic-os.yml#L24-L29)
* configure podman: [here](./roles/basic-os/tasks/basic-os.yml#L31-L47)
* create a podman container for each runner: [here](./roles/runner/tasks/github-runner.yml#L20-34)
* create a systemd service for each runner container: [here](./roles/runner/tasks/github-runner.yml#L36-55)
* create a secret file for each runner container: [here](./roles/runner/tasks/github-runner.yml#L1-18)

In your newly created `github` user's home, you will find 2 files per runners:
```
github@runner-meshtastic:~$ ls -la
.<your-runners-name>-meshtastic.env          # current running job secrets
.<your-runners-name>-meshtastic.make_env.sh  # script generating the "curent running job secrets" file
```

Secrets are generated for each runner container by the `.<your-runners-name>-meshtastic.make_env.sh` script triggered by the [systemd service](./roles/runner/files/github-runner-meshtastic.service.j2#L10) and are written in `.<your-runners-name>-meshtastic.env`.

##### Typical operation
1. Before a container is started, the file `.<your-runners-name>-meshtastic.make_env.sh` is executed and write token values in `.<your-runners-name>-meshtastic.env`
2. The container starts, the file `.<your-runners-name>-meshtastic.env` is picked up inside the container [as a volume](./roles/runner/tasks/github-runner.yml#L30) 
3. The container authenticate on github using the secrets stored in `.<your-runners-name>-meshtastic.env`
4. The meshtastic firmware job is executed
5. The container terminates
6. If the container [terminated smoothly](./roles/runner/files/github-runner-meshtastic.service.j2#L16), back to step `1.` 

## What do I need to adjust before deployment ?

* In the [host.ini](./hosts.ini) file add the hostname FQDN on which you wish to install runners.
* Adjust the [the runner.yml vars](./vars/runner.yml) accordingly: 
```
github_token: meshtastic-github-token          # Provided by the meshtastic crew
user_nickname: github-username                 # Your github nickname
runner_servers:
  your-first-system-fqdn.tld:                  # Your host as written in the host.ini file
    runners:
      - name: runner-1                         # The name of your runner
        runner_location: datacenter-alpha      # The location of your runner
      - name: runner-2
        runner_location: datacenter-bravo
  your-second-system-fqdn.tld:
    runners:
      - name: runner-3
        runner_location: datacenter-charlie
      - name: runner-4
        runner_location: datacenter-delta
```

## How to trigger the deployment ?

You're now ready to deploy your runners ! 

You can trigger a "dry-run" and visualize the changes without applying them like this:
```
ansible-playbook -i hosts.ini runner-meshtastic.yml -DKC
```

If you're happy with the result, trigger and apply changes as follow:
```
ansible-playbook -i hosts.ini runner-meshtastic.yml -DK
```

## And then ?

Do a little review of the system once again to ensure that files and services are populated properly.
Once confident, you can start your runners for the first time like this: 

```
sudo systemctl start github-<your-runner-1-name>-meshtastic.service
sudo systemctl start github-<your-runner-2-name>-meshtastic.service
...
```

If you need to debug something you can check your runner logs like that: 
```
sudo -u github podman logs --tail=40 -f <your-runner-name>-meshtastic
```
