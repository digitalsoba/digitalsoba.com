+++
title =  "How I bootstrap lab servers"
tags = ["ansible", "devops"]
date = "2021-01-12"
+++
Sometimes I want a server up an running as quickly as possible to test some new things out. I could go in manually and set up users, packages, ssh keys, etc, but that'll take ages manually, especially when I spin up multiple servers! This is where Ansible comes into play, mainly the `ansible-pull` command. I can set up a public git repo with all the basic configs I need to hop into a server after it's launched; bonus points if I can use cloud-init or userdata in platforms such as AWS, Digitalocean, or Hetzner. 

## **Directory structure**

Create a bare repository with the following structure. I've installed ansible via pip module so you'll see venv and requirements.txt. Install ansible however you like! 

```bash
❯ tree -I 'venv|.git' -a
.
├── .gitignore <-- adds venv/ to gitignore
├── local.yml <-- entrypoint playbook for ansible-pull
├── requirements.txt <-- pip requires for ansible
└── venv <-- virtual environment for python
└── roles <-- roles directory
    └── bootstrap <-- bootstrap role
        ├── files
        ├── handlers
        ├── tasks
        │   └── main.yml <-- main tasks to execute
        ├── templates
        └── vars
```

## Modify local.yml file to use bootstrap role

Your local.yml file should use a local connection with [localhost](http://localhost) specified as it's hosts. Make sure have `become: true` and the role specified with a tag. Sample below

```yaml
---
- name: Bootstrap role
  hosts: localhost
  connection: local
  become: true
  roles:
    - bootstrap
  tags: bootstrap
```

## Add tasks to the bootstrap role

I'll add a simple task that will install a few packages inside `roles/bootsrap/tasks/main.yml` 

```yaml
---
- name: Install common apt packages
  apt:
    name: "{{ item }}"
    update_cache: yes
    state: present
  loop: "{{ common_packages }}" 
```

The code above uses a loop to install a list of packages from a variables files inside `roles/vars/main.yml`

```yaml
---
common_packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - htop
  - openssh-server
  - net-tools
  - neovim
  - python3
  - software-properties-common
  - sudo
  - tmux
  - vim
  - unattended-upgrades
```

Now the project structure should look like this

```bash
❯ tree -I 'venv|.git' -a
.
├── .gitignore
├── local.yml
├── requirements.txt
└── roles
    └── bootstrap
        ├── files
        ├── handlers
        ├── tasks
        │   └── main.yml
        ├── templates
        └── vars
            └── main.yml

9 directories, 8 files
```

## Testing the playbook with Molecule before deploying

It's a good practice to test these changes locally before deploying into a server. Complex deployments that modify configuration files may cause issues with your server if you're not prepared to catch them beforehand. Check out Jeff Geerling's [Youtube video](https://www.youtube.com/watch?v=FaXVZ60o8L8) for a deep dive on Ansible + Molecule. For the sake of the blog post I'll post my configurations on testing the role on Ubuntu 20.04 using the Docker driver. 

```bash
❯ tree -I 'venv|.git' -a
.
├── files
├── handlers
├── molecule
│   └── default
│       ├── converge.yml
│       ├── molecule.yml
│       └── verify.yml
├── tasks
│   └── main.yml
├── templates
└── vars
    └── main.yml
```

```yaml
---
- name: Converge
  hosts: all
  tasks:
    - name: "Include bootstrap"
      include_role:
        name: "bootstrap"
```

```yaml
---
dependency:
  name: galaxy
driver:
  name: docker
lint: |
  set -e
  yamllint .
  ansible-lint
platforms:
  - name: ubuntu2004
    image: geerlingguy/docker-ubuntu2004-ansible:latest
    pre_build_image: true
    privileged: true
    command: ""
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
provisioner:
  name: ansible
verifier:
  name: ansible
scenario:
  name: default
  test_sequence:
    - lint
    - syntax
    - create
    - converge
    - idempotence
    - verify
    - destroy
```

```yaml
---
# This is an example playbook to execute Ansible tests.
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    - name: Example assertion
      assert:
        that: true
```

## Bootstrapping a server

We currently a simple Ansible playbook that will install a few package but this can be extending to whatever your heart desires! You can view my [personal repo](https://github.com/digitalsoba/bootstrap) for an example of how I configure and bootstrap my servers. When provisioning a server locally in my homelab or on the cloud for lab usage I usually use a root user to run the following commands (Sample below is targeted towards Debian based distros).

```bash
#!/bin/bash

apt update
apt install ansible git -y
ansible-pull -U https://github.com/digitalsoba/bootstrap.git -t server
```