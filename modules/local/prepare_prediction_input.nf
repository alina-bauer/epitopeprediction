//and also do the allele name

process PREPARE_PREDICTION_INPUT {
    label 'process_single'
    tag "${meta.sample}"

    conda "bioconda::mhcgnomes=1.8.4"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mhcgnomes:1.8.4--pyh7cba7a3_0' :
        'quay.io/biocontainers/mhcgnomes:1.8.4--pyh7cba7a3_0' }"

    input:
    tuple val(meta), path(peptide_file), val(supported_lengths_from_tools)

    output:
    tuple val(meta), path("*.csv"), emit: prepared
    path "versions.yml", emit: versions

    script:
    def min_length = (meta.mhc_class == "I") ? params.min_peptide_length : params.min_peptide_length_class2
    def max_length = (meta.mhc_class == "I") ? params.max_peptide_length : params.max_peptide_length_class2

    def lengths_path = file("assets/supported_lengths.json")
    def alleles_path = file("assets/supported_alleles.json")

    """
    prepare_prediction_input.py \
        --input ${peptide_file} \
        --inputtype ${meta.inputtype} \
        --mhc-class ${meta.mhc_class} \
        --min-peptide-length ${min_length} \
        --max-peptide-length ${max_length} \
        --supported-lengths-path '${lengths_path}' \
        --supported-alleles-path '${alleles_path}' \
        --alleles '${meta.alleles}' \
        --tools ${params.tools}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python \$(python --version | sed 's/Python //g')
        netmhcpan \$(echo 4.1)
        netmhcpan \$(cat data/version | sed -s 's/ version/:/g')
        mhcgnomes \$(python -c "from mhcgnomes import version; print(version.__version__)"   )
    END_VERSIONS
    """

}
