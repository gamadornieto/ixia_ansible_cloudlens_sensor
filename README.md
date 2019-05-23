# Demo

This is a didactic example on how to automate the deployment of Ixia Cloudlens CSMP sensors
on Linux VMs using Ansible cloudlens-sensor role.

For didactic purposes, hosts are mapped to <City> and <Country> tags to
allow different Monitoring Groups in the Ixia Cloudlens Manager

```Inventory file

[paris:vars]
City=Paris
Country=France

[marseille:vars]
City=Marseille
Country=France
```

## VM Requirements
Linux VMs with Docker CE, Python3 and Ansible already installed

## cloudlens-sensor role variables

{{Image_Registry_IP }} Ixia Cloudlens CSMP Register IP
{{CSMP_Master_IP }} Ixia Cloudlens CSMP Docker Swarm Master IP  
{{script_action}}  is  [install|uninstall]
{{home_user}} local Linux user that executes the role


```yaml
- hosts: france_sensors
  become: true
  gather_facts: no
  vars:
    script_action: install
  roles:
    - cloudlens-sensor
```

## Dependencies
Ixia Cloudlens CSMP solution deployed.

## License
MIT / BSD

## Author Information
Created in 2019 Gustavo AMADOR NIETO.
