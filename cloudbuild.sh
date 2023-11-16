gcloud builds worker-pools create my-pool \
        --project=my-project \
        --region=europe-west3 \
        --peered-network=projects/entur-project/global/networks/vpc1 \
        --worker-machine-type=e2-medium \
        --worker-disk-size=100
