process GET_PREDICTION_VERSIONS {
    label 'process_low'

    conda (params.enable_conda ? "bioconda::epytope=3.0.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-c3f301504f7fa2e7bf81c3783de19a9990ea3001:12b1b9f040fd92a80629d58f8a558dde4820eb15-0' :
        'quay.io/biocontainers/mulled-v2-c3f301504f7fa2e7bf81c3783de19a9990ea3001:12b1b9f040fd92a80629d58f8a558dde4820eb15-0' }"

    input:
    val external_tool_versions

    output:
    path "versions.csv", emit: versions

    script:
    def external_tools = external_tool_versions.join('\n')

    """
    cat <<-END_VERSIONS > versions.csv
    mhcflurry: \$(mhcflurry-predict --version 2>&1 | sed 's/^mhcflurry //; s/ .*\$//')
    mhcnuggets: \$(python -c "import pkg_resources; print('mhcnuggets' + pkg_resources.get_distribution('mhcnuggets').version)" | sed 's/^mhcnuggets//; s/ .*\$//' )
    epytope: \$(python -c "import pkg_resources; print('epytope' + pkg_resources.get_distribution('epytope').version)" | sed 's/^epytope//; s/ .*\$//')
    END_VERSIONS

    if ! [ -z "${external_tools}" ]
    then
        echo ${external_tools} >> versions.csv
    fi
    """
}


