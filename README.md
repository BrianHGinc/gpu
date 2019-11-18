# Microcom GPU

The aim of this project is to create from scratch a GPU or 'graphics card' for my home-made Microcom computer (details of which will be available on a website sometime in the future!)  This repo is a storage site for the HDL code used to describe the GPU itself and software tools that helped in its development.

When completed, the GPU will support text (via a VT100 compatible console) and graphics modes.  The project is currently in development - see [eevBlog](https://www.eevblog.com/forum/fpga/fpga-vga-controller-for-8-bit-computer/new/#new) for the latest developments and to follow along.

## Getting Started

This repo contains the Verilog HDL code to create a VGA-, and later maybe HDMI-capable video driver using a compatible FPGA of your choice.  You'll need to have a development board with a suitable FPGA with at least 50 KB of internal RAM for later development versions and the software to read the project - in this case [Quartus II from Intel/Altera](https://www.intel.com/content/www/us/en/programmable/downloads/download-center.html).

During early stages of development (for the text-mode design) however, you can get by on an Intel/Altera Cyclone II EP2C5T144C8 dev board, which can be had for less than £14 via everyone's favourite auction website - do a search for ['Cyclone II minimum development board'](https://www.ebay.co.uk/sch/i.html?_from=R40&_trksid=m570.l1313&_nkw=cyclone+II+minimum+development&_sacat=0).

### Prerequisites

* A suitable FPGA development board - detailed above
* The project code in this repo
* An FPGA-compatible IDE for the FPGA to compile and upload the code (Quartus II)
* Note: If you're using a Cyclone II, Quartus II does not support this FPGA after version 13.0sp2

## Built With

* [Quartus II](https://www.intel.com/content/www/us/en/programmable/downloads/download-center.html)

## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on code of conduct, and the process for submitting pull requests to me.

## Authors

* **nockieboy** - *Initial work* - [nockieboy](https://https://github.com/nockieboy)

See also the [eevBlog forum](https://www.eevblog.com/forum/fpga/fpga-vga-controller-for-8-bit-computer/new/#new) for the users who participated and contributed to this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details - although this may be reviewed later when I actually have to time to look at what the MIT licence actually is!

## Acknowledgments

* *BrianHG* - thanks for your support, without which I'd still be struggling to get colour bars to display!
* Inspirational advice and tips from the many users of the eevBlog forums, including *jhpadjustable*, *berni*, *asmi* and many others
