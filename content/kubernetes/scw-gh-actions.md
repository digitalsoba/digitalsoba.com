+++
title =  "Scaleway github actions to deploy into kubernetes"
tags = ["kubernetes", "devops"]
date = "2021-03-05"
+++
These are snippets of a Github actions pipeline I used to deploy this blog on Kubernetes using Scaleway's Kapsule. Detailed post coming soon. 

CI/Deploy to staging on PR
```yaml
name: Build and deploy to staging

on:
  pull_request:
    branches: main
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository and submodules
        uses: actions/checkout@v2
        with:
          submodules: recursive
      - name: Get commit SHA
        id: get_sha
        run: echo "::set-output name=sha_short::$(git rev-parse --short HEAD)"
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v1 
        with:
          registry: ghcr.io
          username: ${{ github.repository_owner }}
          password: ${{ secrets.CR_PAT }} 
      - name: Build and push image
        id: docker_build
        uses: docker/build-push-action@v2
        with:
          context: .
          push: true
          tags: ghcr.io/digitalsoba/digitalsoba.com:${{ steps.get_sha.outputs.sha_short }}
      - name: Image digest
        run: echo ${{ steps.docker_build.outputs.digest }}
  deploy:
    runs-on: ubuntu-latest
    needs: [build]
    steps:
      - name: Checkout repository and submodules
        uses: actions/checkout@v2
        with:
          submodules: recursive
      - name: Get commit SHA
        id: get_sha
        run: echo "::set-output name=sha_short::$(git rev-parse --short HEAD)"
      - name: Install dependencies
        run: |
          sudo curl -o /usr/local/bin/scw -L "https://github.com/scaleway/scaleway-cli/releases/download/v2.2.4/scw-2.2.4-linux-x86_64"
          sudo chmod +x /usr/local/bin/scw
          curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
          curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
          kubectl version --client
          kustomize version
          scw version
      - name: Init SCW
        run: |
          scw init secret-key=${{ secrets.SCW_SECRET_KEY }} send-telemetry=false install-autocomplete=false with-ssh-key=false region=fr-par zone=fr-par-1
      - name: Install kubeconfig 
        run: |
          scw k8s kubeconfig install ${{ secrets.SCW_CLUSTER_ID }}
      - name: Deploy new image to staging namespace
        run: |
          cd k8s/overlays/staging
          kustomize edit set image ghcr.io/digitalsoba/digitalsoba.com:${{ steps.get_sha.outputs.sha_short }}
          kustomize build | kubectl apply -f-
      - name: Cleanup
        run: | 
          rm -rf /home/runner/.kube/config
          rm -rf /home/runner/.config/scw
```

Production deployment
```yaml
name: Build and deploy to production

on:
  push:
    branches: 
      - main
jobs:
  build-and-deploy-to-prod:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository and submodules
        uses: actions/checkout@v2
        with:
          submodules: recursive
      - name: Get commit SHA
        id: get_sha
        run: echo "::set-output name=sha_short::$(git rev-parse --short HEAD)"
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v1 
        with:
          registry: ghcr.io
          username: ${{ github.repository_owner }}
          password: ${{ secrets.CR_PAT }} 
      - name: Build and push image
        id: docker_build
        uses: docker/build-push-action@v2
        with:
          context: .
          push: true
          tags: ghcr.io/digitalsoba/digitalsoba.com:${{ steps.get_sha.outputs.sha_short }}
      - name: Image digest
        run: echo ${{ steps.docker_build.outputs.digest }}
      - name: Install dependencies
        run: |
          sudo curl -o /usr/local/bin/scw -L "https://github.com/scaleway/scaleway-cli/releases/download/v2.2.4/scw-2.2.4-linux-x86_64"
          sudo chmod +x /usr/local/bin/scw
          curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
          curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
          kubectl version --client
          kustomize version
          scw version
      - name: Init SCW
        run: |
          scw init secret-key=${{ secrets.SCW_SECRET_KEY }} send-telemetry=false install-autocomplete=false with-ssh-key=false region=fr-par zone=fr-par-1
      - name: Install kubeconfig 
        run: |
          scw k8s kubeconfig install ${{ secrets.SCW_CLUSTER_ID }}
      - name: Deploy new image to production namespace
        run: |
          cd k8s/overlays/prod
          kustomize edit set image ghcr.io/digitalsoba/digitalsoba.com:${{ steps.get_sha.outputs.sha_short }}
          kustomize build | kubectl apply -f-
      - name: Cleanup
        run: | 
          rm -rf /home/runner/.kube/config
          rm -rf /home/runner/.config/scw
```