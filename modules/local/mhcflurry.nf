process MHCFLURRY {
    label 'process_single'
    tag "${meta.sample}"

    conda "bioconda::mhcflurry=2.0.6"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mhcflurry:2.0.6--pyh7cba7a3_0' :
        'quay.io/biocontainers/mhcflurry:2.0.6--pyh7cba7a3_0' }"

    input:
    tuple val(meta), path(peptide_file)

    output:
    tuple val(meta), path("*.tsv"), emit: predicted
    path "versions.yml", emit: versions

    script:

    if (meta.mhc_class == "II") {
        error("MHCflurry prediction of ${meta.sample} is not possible with MHC class II!")
    }

    """
    mhcflurry-predict 'mhcflurry_input.csv' \\
                        --out '${meta.sample}_mhcflurry_output.tsv'

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python \$(python --version | sed 's/Python //g')
        mhcflurry \$(mhcflurry-predict --version 2>&1 | sed 's/^mhcflurry //; s/ .*\$//')
    END_VERSIONS
    """
}
