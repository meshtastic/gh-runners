### Github runner ansible deployment
TODO

#### What do I need to use it ?
TODO

#### What does it do ?
TODO

#### What to change before deployment ?
TODO

#### How to trigger the deployment ?

Visualize the changes without applying:
```
ansible-playbook -i hosts.ini runner-meshtastic.yml -DCK
```

Applying the changes:
```
ansible-playbook -i hosts.ini runner-meshtastic.yml -DK
```