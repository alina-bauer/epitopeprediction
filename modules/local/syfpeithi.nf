process SYFPEITHI {
    label 'process_single'
    tag "${meta.sample}"

    conda "bioconda::epytope=3.1.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/epytope:3.1.0--pyh5e36f6f_0' :
        'quay.io/biocontainers/epytope:3.1.0--pyh5e36f6f_0' }"

    input:
    tuple val(meta), path(peptide_file)

    output:
    tuple val(meta), path("*.tsv"), emit: predicted
    path "versions.yml", emit: versions

    script:
    def min_length = (meta.mhc_class == "I") ? params.min_peptide_length : params.min_peptide_length_class2
    def max_length = (meta.mhc_class == "I") ? params.max_peptide_length : params.max_peptide_length_class2

    """
    syfpeithi_prediction.py \
        --input ${peptide_file} \
        --alleles '${meta.alleles}' \
        --min_peptide_length ${min_length} \
        --max_peptide_length ${max_length} \
        --output '${meta.sample}_syfpeithi_output.tsv'

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python \$(python --version | sed 's/Python //g')
        epytope \$(python -c "import pkg_resources; print(pkg_resources.get_distribution('epytope').version)")
        syfpeithi \$(python -c "from epytope.EpitopePrediction import EpitopePredictorFactory; print(EpitopePredictorFactory('syfpeithi').version)")
    END_VERSIONS
    """

}
