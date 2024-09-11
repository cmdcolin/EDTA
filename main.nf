#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

params.genomes          = 'genomes/*'
params.species          = 'others'
params.cds              = ''
params.curatedlib       = ''
params.rmlib            = ''
params.sensitive        = false
params.anno             = false
params.rmout            = ''
params.maxdiv           = 40
params.evaluate         = true
params.exclude          = ''
params.maxint           = 5000
params.outdir           = 'results'

// Max resource options
params.max_cpus         = 12
params.max_memory       = '16.GB'
params.max_time         = '1.hour'

// TODO: Check inputed repeat libraries, CDS, etc...
// TODO: Check exclude file

// nf-core -v modules -g https://github.com/GallVp/nxf-components.git install

include { SANITIZE_HEADERS  } from './modules/local/sanitize/main.nf'
include { LTRHARVEST        } from './modules/nf-core/ltrharvest/main.nf'
include { LTRFINDER         } from './modules/nf-core/ltrfinder/main'
include { ANNOSINE          } from './modules/gallvp/annosine/main.nf'
include { TIRLEARNER        } from './modules/gallvp/tirlearner/main.nf'

// Test run: 
// ./main.nf -profile docker,test
// ./main.nf -profile conda,test
workflow {

    // Versions channel
    ch_versions                         = Channel.empty()

    
    ch_genome                           = Channel.fromPath(params.genomes)

    // Create a meta object for each genome
    ch_meta_genome                      = ch_genome.map { genome -> 
                                            meta        = [:]
                                            meta.id     = genome.baseName
                                            
                                            [ meta, genome ]
                                        }

    // MODULE: SANITIZE_HEADERS
    SANITIZE_HEADERS ( ch_meta_genome )

    ch_sanitized_fasta                  = SANITIZE_HEADERS.out.fasta

    // MODULE: LTRHARVEST
    LTRHARVEST ( ch_sanitized_fasta )

    ch_ltrharvest_gff3                  = LTRHARVEST.out.gff3
    ch_ltrharvest_scn                   = LTRHARVEST.out.scn

    ch_versions                         = ch_versions.mix(LTRHARVEST.out.versions)

    // MODULE: LTRFINDER
    LTRFINDER  { ch_sanitized_fasta }

    ch_ltrfinder_gff3                   = LTRFINDER.out.gff
    ch_ltrfinder_scn                    = LTRFINDER.out.scn

    ch_versions                         = ch_versions.mix(LTRFINDER.out.versions)

    // These can also run in parallel
    // MODULE: ANNOSINE
    ANNOSINE (ch_sanitized_fasta, 3)

    // Currently it's a topic, so need to fix that
    ch_versions                         = ch_versions.mix(ANNOSINE.out.versions)
    cb_annosine_seed_sine               = ANNOSINE.out.fa

    // MODULE: TIRLEARNER
    TIRLEARNER (
        ch_sanitized_fasta,
        params.species
    )

    ch_tirlearner_filtered_gff          = TIRLEARNER.out.filtered_gff
    ch_versions                         = ch_versions.mix(TIRLEARNER.out.versions)

}