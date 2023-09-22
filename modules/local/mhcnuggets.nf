process MHCNUGGETS {
    label 'process_low'
    tag "${meta.sample}"

    conda "bioconda::mhcnuggets=2.4.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mhcnuggets:2.4.0--pyh7cba7a3_0' :
        'quay.io/biocontainers/mhcnuggets:2.4.0--pyh7cba7a3_0' }"

    input:
    tuple val(meta), path(peptide_file)

    output:
    tuple val(meta), path("*.tsv"), emit: predicted
    path "versions.yml", emit: versions

    script:
    """
    mhcnuggets_prediction.py --input ${peptide_file}\\
        --output '${meta.sample}_mhcnuggets_output.tsv' \\
        --mhcclass ${meta.mhc_class}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python \$(python --version | sed 's/Python //g')
        mhcnuggets \$(python -c "import pkg_resources; print(pkg_resources.get_distribution('mhcnuggets').version)")
    END_VERSIONS
    """
}
