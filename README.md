# homelab

Infrastructure-as-code for my homelab.

## Devices

- **Cerebro**: Minisforum MS-A2 with Proxmox VE
- **Mind Flayer**: Raspberry Pi with Pi-hole as DNS

## Initial setup on a new device

1. Copy the [env vars / secrets from 1password](https://start.1password.com/open/i?a=JFH5OZK27FBO5POQPIPQH6QSEM&v=guo6c4dlqhqmaxduo7yvxy3stm&i=al5c7kqftihsdkcy6y7xv65pge&h=lighthouse5.1password.com) into `terraform/.env.sh`
2. Run `make init`
3. Install Ansible dependencies: `ansible-galaxy collection install -r ansible/requirements.yml`

## Deploying terraform from local

Run `make plan`.

If all goes well and looks correct, run `make apply`.

## Deploying ansible from local

Configure the host (Cerebro) by running `make host`.

Configure the guests by running `make guests`.
