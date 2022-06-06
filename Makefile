all: out/buildvm.json azuredeploy.json out/vmonly.json
.PHONY: all

out/cloud-config.yml: cloud-config.yml vstsagent.sh BuildVMCloudInit.ps1
	pwsh -nol -nop -noni -File BuildVMCloudInit.ps1 -cloudInitFile cloud-config.yml -installScript vstsagent.sh

out/buildvm.json: buildvm.bicep out/cloud-config.yml custom-script.sh
out/vmonly.json: buildvm.bicep out/cloud-config.yml custom-script.sh
azuredeploy.json: build-infra.bicep network.bicep storage.bicep buildvm.bicep container-registry.bicep

out/%.json: %.bicep
	az bicep build --file $< --outfile $@

azuredeploy.json: build-infra.bicep
	az bicep build --file $< --outfile $@

.PHONY: clean
clean::
	@[ -d out ] && rm -rf out || :
	@[ -f azuredeploy.json ] && rm -f azuredeploy.json || :


