install:
	pip install -r requirements.txt
build:
	ansible-galaxy install -f -r requirements.yml
deploy:
	ansible-playbook -i inventories/test/hosts playbooks/kickstart.yml --vault-password-file=.vault_pass --private-key "~/.ssh/id_rsa" -v
