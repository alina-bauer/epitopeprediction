#!/usr/bin/env python
# Written by Jonas Scheid, Alina Bauer and released under the MIT license.

import argparse
import pandas as pd
import typing
import sys
import logging
from functools import reduce
import json
import mhcgnomes

# Create a logger
logging.basicConfig(
    filename="prepare_prediction_outputs.log",
    filemode="w",
    level=logging.DEBUG,
    format="%(asctime)s %(levelname)s %(message)s",
    force=True,
)


def parse_args(argv=None) -> typing.List[str]:
    """
    Parse command line arguments
    :param argv: list of arguments
    :return: parsed arguments
    """
    parser = argparse.ArgumentParser(description="Adjust prediction inputs to predictors")
    parser.add_argument("--input", required=True, type=str, help="Path to input file")
    parser.add_argument("--inputtype", required=True, type=str, help="Input type of input file")
    parser.add_argument("--mhc-class", required=True, type=str, help="Mhc class 1 oder 2")
    parser.add_argument("--min-peptide-length", type=int, help="Minimum length of the peptides")
    parser.add_argument("--max-peptide-length", type=int, help="Maximum length of the peptides")
    parser.add_argument("--supported-lengths-path",type=str, help="Path to json file with supported lengths for each tool")
    parser.add_argument("--supported-alleles-path",type=str, help="Path to json file with supported alleles for each tool")
    parser.add_argument("--tools", type=str, help="List of tools that should be used")
    parser.add_argument("--alleles", type=str, help="Semicolon-separated list of alleles that should be used")

    return parser.parse_args(argv)


class InputFileGenerator:
    def __init__(self, predictor, input_df, thresholds, supported_alleles):
        self.predictor = predictor
        self.input_df = input_df
        self.thresholds = thresholds
        self.supported_alleles = supported_alleles

    def get_input_df(self):
        return self.input_df

    def check_requested_alleles(self, requested_alleles):
        requested_alleles = [mhcgnomes.parse(allele).to_string() for allele in requested_alleles]
        filtered_alleles = []
        for allele in requested_alleles:
            if allele in self.supported_alleles:
                filtered_alleles.append(allele)
            else:
                logging.warning(f"Allele {allele} not supported by {self.predictor}")
                logging.warning(f"supported alleles {self.supported_alleles} allele {allele}")
        if filtered_alleles == []:
            logging.error(f"No alleles supported by {self.predictor}")
            sys.exit(1)
        self.supported_alleles = filtered_alleles

    def check_peptide_lengths(self, min_peptide_length, max_peptide_length):
        self.input_df = self.input_df[self.input_df["peptide_length"].between(min_peptide_length, max_peptide_length)]
        if self.input_df.empty:
            logging.error(f"No peptides with length between {min_peptide_length} and {max_peptide_length}")
            sys.exit(1)

    def check_input_nonempty(self):
        if self.input_df.empty:
            logging.error(f"No peptides for prediction of {self.predictor}")
            sys.exit(1)

    def format_prediction_input(self):
        if self.predictor == "syfpeithi":
            self.input_df = self._format_syfpeithi_input()
        elif self.predictor == "mhcflurry":
            self.input_df = self._format_mhcflurry_input()
        elif self.predictor == "mhcnuggets":
            self.input_df = self._format_mhcnuggets_input()
        elif self.predictor == "netmhcpan":
            self.input_df = self._format_netmhcpan_input()
        elif self.predictor == "netmhciipan":
            self.input_df = self._format_netmhciipan_input()
        else:
            logging.error(f"Predictor {self.predictor} not supported")
            sys.exit(1)

    def _format_syfpeithi_input(self):
        #the input for the predictor is as minimal as possible, only sequence column is needed
        df = self.input_df[["sequence"]]
        return df

    def _format_mhcflurry_input(self):
        #The input CSV file is expected to contain columns "allele", "peptide", and, optionally, "n_flank", and "c_flank".
        #pair every allele with every peptide
        peptides = self.input_df["sequence"].astype(str).tolist()
        #get column sequence of df as list of strings
        alleles = self.supported_alleles
        #pair every allele with every peptide
        df = pd.DataFrame([(allele, peptide) for allele in alleles for peptide in peptides], columns=["allele", "peptide"])
        return df

    def _format_mhcnuggets_input(self):
        peptides = self.input_df["sequence"].astype(str).tolist()
        df = pd.DataFrame(peptides, columns=["peptide"])
        #mhcnuggets needs short-form representation of alleles without *
        alleles = [allele.replace("*", "") for allele in self.supported_alleles]
        alleles = ";".join(alleles)
        df["allele"] = [alleles]*len(df)
        return df

    def _format_netmhcpan_input(self):
        df = self.input_df
        return df

    def _format_netmhciipan_input(self):
        NotImplementedError()


def main():
    args = parse_args()

    requested_alleles = args.alleles.split(";") if args.alleles is not None else logging.error("No alleles specified")
    tools = args.tools.split(",") if args.tools is not None else logging.error("No tools specified")

    with open(args.supported_lengths_path, 'r') as json_file:
        supported_lengths = json.load(json_file)
    with open(args.supported_alleles_path, 'r') as json_file:
        supported_alleles = json.load(json_file)

    #convert to df and add column with peptide lengths
    #TODO: implement for the other input types
    if args.inputtype == "peptide":
        input = pd.read_csv(args.input, sep="\t")
        input["peptide_length"] = input["sequence"].str.len()

    for tool in tools:
        thresholds = (supported_lengths[tool]["min"], supported_lengths[tool]["max"])
        if tool not in ('syfpeithi', 'mhcflurry', 'mhcnuggets', 'netmhcpan', 'netmhciipan'):
            logging.error(f"Predictor not supported")
            sys.exit(1)

        # Refactor prediction output to only the necessary columns
        generated_file = InputFileGenerator(predictor=tool, input_df=input, thresholds=thresholds, supported_alleles=supported_alleles[tool])
        generated_file.check_requested_alleles(requested_alleles)
        generated_file.check_peptide_lengths(args.min_peptide_length, args.max_peptide_length)
        generated_file.format_prediction_input()

        generated_file.get_input_df().to_csv(f"{tool}_input.csv", index=False)

if __name__ == "__main__":
    main()
