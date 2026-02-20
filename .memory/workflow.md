# Development Workflow

## Step-by-Step Development

1. **Create skeleton**: `/setup-pipeline my-pipeline`
2. **Plan workflow** (inputs -> processes -> outputs)
3. **Add processes** one at a time using `/add-process`
4. **Test stubs**: `nextflow run main.nf -profile test -stub`
5. **Build Docker container** (if custom): `cd docker && ./build_and_push.sh`
6. **Test locally**: `nextflow run main.nf -profile test`
7. **Test on GCP** with test data
8. **Production run** with full dataset

## Adding a Process (what /add-process does)

For each new process, the following files are created/modified:

1. `modules/local/<process_name>/main.nf` - New process module
2. `main.nf` - Add include statement + wire into workflow
3. `conf/modules.config` - Add withName resource block
4. `docker/Dockerfile` - Update if custom container needed
5. `nextflow.config` - Add new params if needed
